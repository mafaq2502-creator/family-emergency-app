import * as admin from 'firebase-admin';
import {activeSafetySlot, defaultSafetyPreferences, validSafetyPreferences} from './safety-policy.js';
import {randomBytes} from 'node:crypto';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';

admin.initializeApp();
const db = admin.firestore();

type GroupData = {
  ownerId?: unknown;
  memberIds?: unknown;
  roles?: unknown;
  emergencyRecipientIds?: unknown;
  status?: unknown;
};

const FREE_MAX_OWNED = 1;
const FREE_MAX_JOINED = 1;
const FREE_MAX_MEMBERS = 3;
const PREMIUM_MAX_MEMBERS = 11;

function isPremium(profile: admin.firestore.DocumentData | undefined): boolean {
  return profile?.planTier === 'premium' && profile?.subscriptionStatus === 'active';
}

function maxMembers(profile: admin.firestore.DocumentData | undefined): number {
  return isPremium(profile) ? PREMIUM_MAX_MEMBERS : FREE_MAX_MEMBERS;
}

function inviteCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = randomBytes(24);
  return [...bytes].map(value => alphabet[value % alphabet.length]).join('');
}

function requireName(data: unknown): string {
  const name = String((data as {name?: unknown} | null)?.name ?? '').trim();
  if (name.length < 2 || name.length > 60 || /[\u0000-\u001f\u007f]/.test(name)) {
    throw new HttpsError('invalid-argument', 'Please enter a valid Circle name.');
  }
  return name;
}

async function activeCirclesFor(
  transaction: admin.firestore.Transaction,
  userId: string,
): Promise<admin.firestore.QuerySnapshot> {
  return transaction.get(db.collection('groups')
    .where('memberIds', 'array-contains', userId)
    .where('status', '==', 'active'));
}

function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string' && item.length > 0) : [];
}

function roles(value: unknown): Record<string, string> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return {};
  return Object.fromEntries(Object.entries(value).filter((entry): entry is [string, string] => typeof entry[1] === 'string'));
}

function requireCircleId(data: unknown): string {
  const circleId = String((data as {circleId?: unknown} | null)?.circleId ?? '').trim();
  if (!circleId || circleId.length > 128) throw new HttpsError('invalid-argument', 'The Circle ID is invalid.');
  return circleId;
}

function ensureActiveGroup(group: admin.firestore.DocumentSnapshot): GroupData {
  if (!group.exists) throw new HttpsError('not-found', 'This family Circle is no longer available.');
  const data = group.data() as GroupData;
  if (data.status !== undefined && data.status !== 'active') {
    throw new HttpsError('failed-precondition', 'This family Circle is no longer active.');
  }
  return data;
}

function profileCircleCleanup(circleId: string, profileData: admin.firestore.DocumentData | undefined) {
  const update: Record<string, unknown> = {
    circleIds: FieldValue.arrayRemove(circleId),
    ownedCircleIds: FieldValue.arrayRemove(circleId),
    joinedCircleIds: FieldValue.arrayRemove(circleId),
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (profileData?.activeCircleId === circleId) {
    update.activeCircleId = FieldValue.delete();
  }
  if (profileData?.pendingJoinCircleId === circleId) {
    update.pendingJoinCircleId = FieldValue.delete();
    update.pendingJoinInviteId = FieldValue.delete();
  }
  return update;
}

async function writeNotification(userId: string, groupId: string, title: string, body: string, type: string, emergencyId?: string) {
  await db.collection('users').doc(userId).collection('notifications').add({groupId, title, body, type, emergencyId: emergencyId ?? null, isRead: false, createdAt: FieldValue.serverTimestamp()});
}

async function sendPushNotification(userId: string, groupId: string, title: string, body: string, type: string, emergencyId?: string) {
  const devices = await db.collection('users').doc(userId).collection('devices')
    .where('status', '==', 'active').where('notificationsEnabled', '==', true).get();
  const tokens = [...new Set(devices.docs.map(doc => doc.data().fcmToken).filter((token): token is string => typeof token === 'string' && token.length > 0))];
  if (tokens.length === 0) return false;
  let failed = 0;
  for (let offset = 0; offset < tokens.length; offset += 500) {
  const chunk = tokens.slice(offset, offset + 500);
  const response = await admin.messaging().sendEachForMulticast({
    tokens: chunk,
    notification: {title, body},
    data: {type, groupId, recipientUid: userId, ...(emergencyId ? {emergencyId} : {})},
    android: {
      priority: type.startsWith('emergency') ? 'high' : 'normal',
      notification: {channelId: type.startsWith('emergency') ? 'emergency_sos' : 'family_activity'},
    },
  });
  failed += response.failureCount;
  const invalidCodes = new Set(['messaging/invalid-registration-token', 'messaging/registration-token-not-registered']);
  await Promise.all(response.responses.map(async (result, index) => {
    if (result.success || !invalidCodes.has(result.error?.code ?? '')) return;
    const stale = devices.docs.filter(doc => doc.data().fcmToken === chunk[index]);
    await Promise.all(stale.map(doc => db.runTransaction(async transaction => {
      const latest = await transaction.get(doc.ref);
      if (latest.data()?.fcmToken === chunk[index]) {
        transaction.update(doc.ref, {fcmToken: FieldValue.delete(), pushUpdatedAt: FieldValue.serverTimestamp()});
      }
    })));
  }));
  }
  if (failed > 0) throw new Error(`Push provider rejected ${failed} device deliveries.`);
  return true;
}

async function deliverNotification(userId: string, groupId: string, title: string, body: string, type: string, emergencyId?: string) {
  await Promise.all([
    writeNotification(userId, groupId, title, body, type, emergencyId),
    sendPushNotification(userId, groupId, title, body, type, emergencyId),
  ]);
}

export const sendEmergencyToRecipients = onDocumentCreated('groups/{groupId}/emergencies/{emergencyId}', async event => {
  const emergency = event.data?.data(); if (!emergency) return;
  const group = await db.collection('groups').doc(event.params.groupId).get();
  const members = new Set(strings(group.data()?.memberIds));
  const recipients = strings(emergency.recipientIds)
    .filter(id => members.has(id) && id !== emergency.senderId);
  await Promise.all(recipients.map(async userId => deliverNotification(userId, event.params.groupId, 'Emergency SOS', `${emergency.senderName ?? 'A member'} needs help. Tap to acknowledge.`, 'emergency', event.params.emergencyId)));
  await safetySignal(emergency.senderId, 'emergencyAlerts', `sos_${event.params.emergencyId}`, 'Emergency SOS', `${emergency.senderName ?? 'Your Safety User'} needs help.`, recipients);
});

export const createCircle = onCall(async request => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const name = requireName(request.data);
  const groupRef = db.collection('groups').doc();
  const profileRef = db.collection('users').doc(userId);
  await db.runTransaction(async transaction => {
    const [profile, owned] = await Promise.all([
      transaction.get(profileRef),
      transaction.get(db.collection('groups').where('ownerId', '==', userId).where('status', '==', 'active')),
    ]);
    const profileData = profile.data();
    if (!isPremium(profileData) && owned.size >= FREE_MAX_OWNED) {
      throw new HttpsError('resource-exhausted', 'Your Free Plan allows you to create 1 Circle. Upgrade to Premium to create more.');
    }
    const now = FieldValue.serverTimestamp();
    transaction.create(groupRef, {
      name, ownerId: userId, memberIds: [userId], roles: {[userId]: 'owner'},
      emergencyRecipientIds: [userId], status: 'active',
      ownerPlanTier: isPremium(profileData) ? 'premium' : 'free', createdAt: now, updatedAt: now,
    });
    transaction.create(groupRef.collection('memberships').doc(userId), {
      userId, displayName: profileData?.name ?? request.auth?.token.name ?? '',
      email: request.auth?.token.email ?? '', relationship: profileData?.relationship ?? 'Self',
      circleRole: 'owner', status: 'active', joinedAt: now, updatedAt: now,
    });
    transaction.set(profileRef, {
      onboardingCompleted: true, activeCircleId: groupRef.id,
      circleIds: FieldValue.arrayUnion(groupRef.id), ownedCircleIds: FieldValue.arrayUnion(groupRef.id),
      updatedAt: now,
    }, {merge: true});
  });
  return {circleId: groupRef.id};
});

export const createCircleInvite = onCall(async request => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const circleId = requireCircleId(request.data);
  const circleRole = request.data?.circleRole === 'child' ? 'child' : 'adult';
  const code = inviteCode();
  const inviteRef = db.collection('circleInvites').doc(code);
  await db.runTransaction(async transaction => {
    const groupRef = db.collection('groups').doc(circleId);
    const groupSnapshot = await transaction.get(groupRef);
    const groupData = ensureActiveGroup(groupSnapshot);
    const actorRole = roles(groupData.roles)[userId];
    if (!strings(groupData.memberIds).includes(userId) || !['owner', 'parent', 'admin'].includes(actorRole)) {
      throw new HttpsError('permission-denied', 'Only a Circle owner or parent can create invitations.');
    }
    const ownerProfile = await transaction.get(db.collection('users').doc(String(groupData.ownerId)));
    const activeInvites = await transaction.get(db.collection('circleInvites')
      .where('circleId', '==', circleId).where('status', '==', 'active'));
    const reserved = activeInvites.docs.filter(doc => {
      const expiresAt = doc.data().expiresAt;
      return expiresAt instanceof Timestamp && expiresAt.toMillis() > Date.now();
    }).length;
    if (strings(groupData.memberIds).length + reserved >= maxMembers(ownerProfile.data())) {
      throw new HttpsError('resource-exhausted', isPremium(ownerProfile.data()) ? 'This Circle has reached its member limit.' : 'Free Plan member limit reached.');
    }
    const now = FieldValue.serverTimestamp();
    let direct: admin.firestore.DocumentData | undefined;
    if (request.data?.relationshipId) {
      if (groupData.ownerId !== userId) throw new HttpsError('permission-denied', 'Only the owner may invite an Added User.');
      const relationship = await transaction.get(db.collection('users').doc(userId).collection('safetyUsers').doc(safeId(request.data.relationshipId)));
      direct = relationship.data();
      if (!direct || direct.status !== 'connected') throw new HttpsError('failed-precondition', 'Select a connected Added User.');
      const pending = await transaction.get(groupRef.collection('joinRequests').doc(direct.targetUserId));
      if (pending.data()?.status === 'pending') throw new HttpsError('already-exists', 'This user already has a pending join request.');
      if (strings(groupData.memberIds).includes(direct.targetUserId) || activeInvites.docs.some(doc => doc.data().targetUserId === direct!.targetUserId && doc.data().expiresAt.toMillis() > Date.now())) throw new HttpsError('already-exists', 'User already belongs to this Circle or has an active invite.');
      const targetProfile = await transaction.get(db.collection('users').doc(direct.targetUserId));
      const targetCircles = await activeCirclesFor(transaction, direct.targetUserId);
      if (!isPremium(targetProfile.data()) && targetCircles.docs.filter(doc => doc.data().ownerId !== direct!.targetUserId).length >= FREE_MAX_JOINED) throw new HttpsError('resource-exhausted', 'This user has reached their joined Circle limit.');
    }
    transaction.create(inviteRef, {
      circleId, circleName: groupSnapshot.data()?.name, createdBy: userId,
      createdAt: now, expiresAt: Timestamp.fromMillis(Date.now() + 7 * 86400000),
      status: 'active', inviteType: 'singleUse', maxUses: 1, useCount: 0,
      requiresApproval: true, circleRole,
      ...(direct ? {targetUserId: direct.targetUserId, email: direct.email, senderName: ownerProfile.data()?.name ?? 'Circle owner', senderPhotoUrl: ownerProfile.data()?.photoUrl ?? null} : {}),
    });
    transaction.update(groupRef, {updatedAt: now});
    if (direct) queueInvitation(transaction, code, {targetUserId: direct.targetUserId, email: direct.email, ownerId: userId, senderName: request.auth?.token.name ?? 'A user', circleName: groupSnapshot.data()?.name, type: 'circle_invite'});
  });
  const group = await db.collection('groups').doc(circleId).get();
  return {id: code, circleId, circleName: String(group.data()?.name ?? 'Family Circle'),
    createdBy: userId, expiresAtMillis: Date.now() + 7 * 86400000, status: 'active', maxUses: 1,
    useCount: 0, requiresApproval: true, circleRole, emailStatus: request.data?.relationshipId ? (process.env.INVITATION_EMAIL_ENDPOINT && process.env.INVITATION_EMAIL_TOKEN && process.env.INVITATION_LINK_BASE ? 'queued' : 'configuration-required') : 'not-requested'};
});

export const revokeCircleInvite = onCall(async request => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const code = String(request.data?.code ?? '').trim().toUpperCase();
  await db.runTransaction(async transaction => {
    const ref = db.collection('circleInvites').doc(code);
    const invite = await transaction.get(ref);
    const data = invite.data();
    if (!invite.exists || !data) throw new HttpsError('not-found', 'This invitation is no longer available.');
    const groupData = ensureActiveGroup(await transaction.get(db.collection('groups').doc(String(data.circleId))));
    if (!['owner', 'parent', 'admin'].includes(roles(groupData.roles)[userId])) throw new HttpsError('permission-denied', 'You cannot revoke this invitation.');
    if (data.status !== 'active') throw new HttpsError('failed-precondition', 'This invitation is no longer active.');
    const now = FieldValue.serverTimestamp();
    transaction.update(ref, {status: 'revoked', revokedBy: userId, revokedAt: now, updatedAt: now});
  });
  return {code};
});

export const cancelCircleJoinRequest = onCall(async request => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const circleId = requireCircleId(request.data);
  await db.runTransaction(async transaction => {
    const requestRef = db.collection('groups').doc(circleId).collection('joinRequests').doc(userId);
    const joinRequest = await transaction.get(requestRef);
    const data = joinRequest.data();
    if (!joinRequest.exists || data?.status !== 'pending') return;
    const inviteRef = db.collection('circleInvites').doc(String(data.inviteId));
    const invite = await transaction.get(inviteRef);
    const now = FieldValue.serverTimestamp();
    transaction.update(requestRef, {status: 'cancelled', updatedAt: now});
    if (invite.data()?.status === 'active' && invite.data()?.reservedBy === userId) {
      transaction.update(inviteRef, {
        status: 'revoked', revokedBy: userId, revokedAt: now,
        reservedBy: FieldValue.delete(), reservedAt: FieldValue.delete(), updatedAt: now,
      });
    }
    transaction.set(db.collection('users').doc(userId), {pendingJoinCircleId: FieldValue.delete(), pendingJoinInviteId: FieldValue.delete(), updatedAt: now}, {merge: true});
  });
  return {circleId};
});

export const submitCircleJoinRequest = onCall(async request => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const code = String(request.data?.code ?? '').trim().toUpperCase();
  if (!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{24}$/.test(code)) throw new HttpsError('invalid-argument', 'This invitation is invalid.');
  let result: Record<string, unknown> = {};
  await db.runTransaction(async transaction => {
    const inviteRef = db.collection('circleInvites').doc(code);
    const inviteSnapshot = await transaction.get(inviteRef);
    const inviteData = inviteSnapshot.data();
    if (!inviteSnapshot.exists || !inviteData) throw new HttpsError('not-found', 'This invitation is invalid.');
    if (inviteData.targetUserId) recipient(request, inviteData);
    if (inviteData.status === 'consumed') throw new HttpsError('already-exists', 'This invitation has already been used.');
    if (inviteData.status === 'revoked') throw new HttpsError('failed-precondition', 'This invitation has been revoked.');
    if (!(inviteData.expiresAt instanceof Timestamp) || inviteData.expiresAt.toMillis() <= Date.now()) throw new HttpsError('deadline-exceeded', 'This invitation has expired.');
    if (inviteData.status !== 'active' || (inviteData.reservedBy && inviteData.reservedBy !== userId)) throw new HttpsError('already-exists', 'This invitation has already been used.');
    const circleId = String(inviteData.circleId);
    const groupRef = db.collection('groups').doc(circleId);
    const profileRef = db.collection('users').doc(userId);
    const [groupSnapshot, profile, memberships] = await Promise.all([
      transaction.get(groupRef), transaction.get(profileRef), activeCirclesFor(transaction, userId),
    ]);
    const groupData = ensureActiveGroup(groupSnapshot);
    if (strings(groupData.memberIds).includes(userId)) {
      result = {circleId, circleName: inviteData.circleName, status: 'existingMember'};
      return;
    }
    const joinedCount = memberships.docs.filter(doc => doc.data().ownerId !== userId).length;
    if (!isPremium(profile.data()) && joinedCount >= FREE_MAX_JOINED) throw new HttpsError('resource-exhausted', 'Your Free Plan allows you to join 1 additional Circle. Upgrade to Premium to join more.');
    const ownerProfile = await transaction.get(db.collection('users').doc(String(groupData.ownerId)));
    if (strings(groupData.memberIds).length >= maxMembers(ownerProfile.data())) throw new HttpsError('resource-exhausted', isPremium(ownerProfile.data()) ? 'This Circle is full.' : 'Free Plan member limit reached.');
    const requestRef = groupRef.collection('joinRequests').doc(userId);
    const existing = await transaction.get(requestRef);
    if (existing.data()?.status === 'pending' && inviteData.reservedBy === userId) {
      result = {circleId, circleName: inviteData.circleName, status: 'alreadyPending'};
      return;
    }
    const now = FieldValue.serverTimestamp();
    transaction.set(requestRef, {
      circleId, userUid: userId, inviteId: code, displayName: profile.data()?.name ?? request.auth?.token.name ?? 'Family member',
      email: profile.data()?.email ?? request.auth?.token.email ?? '', relationship: profile.data()?.relationship ?? 'Family member',
      circleRole: inviteData.circleRole === 'child' ? 'child' : 'adult', status: 'pending', requestedAt: now, updatedAt: now,
    });
    transaction.update(inviteRef, {reservedBy: userId, reservedAt: now, updatedAt: now});
    transaction.set(profileRef, {pendingJoinCircleId: circleId, pendingJoinInviteId: code, updatedAt: now}, {merge: true});
    result = {circleId, circleName: inviteData.circleName, status: 'pending'};
  });
  return result;
});

export const reviewCircleJoinRequest = onCall(async request => {
  const reviewerId = request.auth?.uid;
  if (!reviewerId) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const circleId = requireCircleId(request.data);
  const targetId = String(request.data?.userId ?? '').trim();
  const approve = request.data?.approve === true;
  await db.runTransaction(async transaction => {
    const groupRef = db.collection('groups').doc(circleId);
    const requestRef = groupRef.collection('joinRequests').doc(targetId);
    const [groupSnapshot, joinRequest, targetProfile, targetGroups] = await Promise.all([
      transaction.get(groupRef), transaction.get(requestRef), transaction.get(db.collection('users').doc(targetId)), activeCirclesFor(transaction, targetId),
    ]);
    const groupData = ensureActiveGroup(groupSnapshot);
    const reviewerRole = roles(groupData.roles)[reviewerId];
    if (!strings(groupData.memberIds).includes(reviewerId) || !['owner', 'parent', 'admin'].includes(reviewerRole)) throw new HttpsError('permission-denied', 'This join request cannot be reviewed.');
    const requestData = joinRequest.data();
    if (!joinRequest.exists || requestData?.status !== 'pending') throw new HttpsError('failed-precondition', 'This join request was already reviewed.');
    const inviteRef = db.collection('circleInvites').doc(String(requestData.inviteId));
    const invite = await transaction.get(inviteRef);
    const inviteData = invite.data();
    const now = FieldValue.serverTimestamp();
    if (!approve) {
      transaction.update(requestRef, {status: 'rejected', reviewedBy: reviewerId, reviewedAt: now, updatedAt: now});
      if (inviteData?.status === 'active' && inviteData.reservedBy === targetId) {
        transaction.update(inviteRef, {
          status: 'revoked', revokedBy: reviewerId, revokedAt: now,
          reservedBy: FieldValue.delete(), reservedAt: FieldValue.delete(), updatedAt: now,
        });
      }
      transaction.set(targetProfile.ref, {pendingJoinCircleId: FieldValue.delete(), pendingJoinInviteId: FieldValue.delete(), updatedAt: now}, {merge: true});
      return;
    }
    if (!invite.exists || !inviteData || inviteData.status !== 'active' || inviteData.reservedBy !== targetId || !(inviteData.expiresAt instanceof Timestamp) || inviteData.expiresAt.toMillis() <= Date.now()) throw new HttpsError('failed-precondition', inviteData?.status === 'consumed' ? 'This invitation has already been used.' : 'This invitation is no longer active.');
    const ownerProfile = await transaction.get(db.collection('users').doc(String(groupData.ownerId)));
    if (strings(groupData.memberIds).length >= maxMembers(ownerProfile.data())) throw new HttpsError('resource-exhausted', 'Free Plan member limit reached.');
    const joinedCount = targetGroups.docs.filter(doc => doc.data().ownerId !== targetId).length;
    if (!isPremium(targetProfile.data()) && joinedCount >= FREE_MAX_JOINED) throw new HttpsError('resource-exhausted', 'Your Free Plan allows you to join 1 additional Circle. Upgrade to Premium to join more.');
    const assignedRole = requestData.circleRole === 'child' ? 'child' : 'adult';
    const nextRoles = roles(groupData.roles); nextRoles[targetId] = assignedRole;
    transaction.update(groupRef, {memberIds: FieldValue.arrayUnion(targetId), roles: nextRoles, lastApprovedUserId: targetId, updatedAt: now});
    transaction.set(groupRef.collection('memberships').doc(targetId), {userId: targetId, displayName: requestData.displayName, email: requestData.email, relationship: requestData.relationship, circleRole: assignedRole, status: 'active', joinedAt: now, updatedAt: now});
    transaction.update(requestRef, {status: 'approved', reviewedBy: reviewerId, reviewedAt: now, updatedAt: now});
    transaction.update(inviteRef, {status: 'consumed', useCount: 1, consumedBy: targetId, consumedAt: now, updatedAt: now});
    transaction.set(targetProfile.ref, {onboardingCompleted: true, activeCircleId: circleId, circleIds: FieldValue.arrayUnion(circleId), joinedCircleIds: FieldValue.arrayUnion(circleId), pendingJoinCircleId: FieldValue.delete(), pendingJoinInviteId: FieldValue.delete(), updatedAt: now}, {merge: true});
  });
  return {circleId, userId: targetId, approved: approve};
});

export const notifyEmergencyAcknowledgement = onDocumentUpdated('groups/{groupId}/emergencies/{emergencyId}', async event => {
  const before = event.data?.before.data(); const after = event.data?.after.data();
  if (!before || !after || before.status === after.status || after.status !== 'acknowledged') return;
  await deliverNotification(after.senderId, event.params.groupId, 'SOS acknowledged', `${after.acknowledgedByName ?? 'A group member'} acknowledged your emergency.`, 'emergencyAcknowledged', event.params.emergencyId);
});

export const syncOwnedCirclePlan = onDocumentUpdated('users/{userId}', async event => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after || (before?.planTier === after.planTier && before?.subscriptionStatus === after.subscriptionStatus)) return;
  const tier = isPremium(after) ? 'premium' : 'free';
  const groups = await db.collection('groups').where('ownerId', '==', event.params.userId).where('status', '==', 'active').get();
  if (groups.empty) return;
  const batch = db.batch();
  groups.docs.forEach(group => batch.update(group.ref, {ownerPlanTier: tier, updatedAt: FieldValue.serverTimestamp()}));
  await batch.commit();
});

export const removeCircleMember = onCall(async request => {
  const actorId = request.auth?.uid;
  if (!actorId) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const circleId = requireCircleId(request.data);
  const targetId = String(request.data?.memberUserId ?? '').trim();
  if (!targetId || targetId.length > 128) throw new HttpsError('invalid-argument', 'The member ID is invalid.');
  if (targetId === actorId) throw new HttpsError('failed-precondition', 'Use Leave Circle to remove your own membership.');

  await db.runTransaction(async transaction => {
    const groupRef = db.collection('groups').doc(circleId);
    const membershipRef = groupRef.collection('memberships').doc(targetId);
    const profileRef = db.collection('users').doc(targetId);
    const [group, membership, profile] = await Promise.all([
      transaction.get(groupRef), transaction.get(membershipRef), transaction.get(profileRef),
    ]);
    const groupData = ensureActiveGroup(group);
    const groupRoles = roles(groupData.roles);
    const actorRole = groupRoles[actorId];
    const targetRole = groupRoles[targetId];
    const actorCanRemove = strings(groupData.memberIds).includes(actorId) &&
      (actorRole === 'owner' ||
        (actorRole === 'parent' &&
          (targetRole === 'adult' || targetRole === 'child')));
    if (!actorCanRemove) throw new HttpsError('permission-denied', 'You cannot remove this Circle member.');
    if (targetRole === 'owner') throw new HttpsError('failed-precondition', 'The Circle owner cannot be removed.');
    if (!membership.exists || membership.data()?.status !== 'active') {
      throw new HttpsError('not-found', 'This member is no longer part of the Circle.');
    }

    delete groupRoles[targetId];
    const now = FieldValue.serverTimestamp();
    transaction.update(groupRef, {
      memberIds: FieldValue.arrayRemove(targetId),
      roles: groupRoles,
      emergencyRecipientIds: strings(groupData.emergencyRecipientIds).filter(id => id !== targetId),
      updatedAt: now,
    });
    transaction.update(membershipRef, {status: 'removed', endedAt: now, endedBy: actorId, updatedAt: now});
    if (profile.exists) transaction.set(profileRef, profileCircleCleanup(circleId, profile.data()), {merge: true});
  });
  return {circleId, memberUserId: targetId};
});

export const leaveCircle = onCall(async request => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const circleId = requireCircleId(request.data);

  await db.runTransaction(async transaction => {
    const groupRef = db.collection('groups').doc(circleId);
    const membershipRef = groupRef.collection('memberships').doc(userId);
    const profileRef = db.collection('users').doc(userId);
    const [group, membership, profile] = await Promise.all([
      transaction.get(groupRef), transaction.get(membershipRef), transaction.get(profileRef),
    ]);
    const groupData = ensureActiveGroup(group);
    const groupRoles = roles(groupData.roles);
    if (groupData.ownerId === userId || groupRoles[userId] === 'owner') {
      throw new HttpsError('failed-precondition', 'The owner must delete the Circle or transfer ownership before leaving.');
    }
    if (!strings(groupData.memberIds).includes(userId) || !membership.exists || membership.data()?.status !== 'active') {
      throw new HttpsError('not-found', 'You are no longer a member of this Circle.');
    }

    delete groupRoles[userId];
    const now = FieldValue.serverTimestamp();
    transaction.update(groupRef, {
      memberIds: FieldValue.arrayRemove(userId),
      roles: groupRoles,
      emergencyRecipientIds: strings(groupData.emergencyRecipientIds).filter(id => id !== userId),
      updatedAt: now,
    });
    transaction.update(membershipRef, {status: 'left', endedAt: now, endedBy: userId, updatedAt: now});
    if (profile.exists) transaction.set(profileRef, profileCircleCleanup(circleId, profile.data()), {merge: true});
  });
  return {circleId};
});

export const deleteCircle = onCall(async request => {
  const userId = request.auth?.uid;
  if (!userId) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const circleId = requireCircleId(request.data);

  await db.runTransaction(async transaction => {
    const groupRef = db.collection('groups').doc(circleId);
    const membershipsQuery = groupRef.collection('memberships');
    const [group, memberships] = await Promise.all([
      transaction.get(groupRef), transaction.get(membershipsQuery),
    ]);
    const groupData = ensureActiveGroup(group);
    if (!strings(groupData.memberIds).includes(userId) ||
        groupData.ownerId !== userId || roles(groupData.roles)[userId] !== 'owner') {
      throw new HttpsError('permission-denied', 'Only the Circle owner can delete this Circle.');
    }
    const [invites, requests, devices] = await Promise.all([
      transaction.get(db.collection('circleInvites').where('circleId', '==', circleId)),
      transaction.get(groupRef.collection('joinRequests').where('status', '==', 'pending')),
      transaction.get(groupRef.collection('devices')),
    ]);
    const userIds = [...new Set([...memberships.docs.map(member => member.id), ...requests.docs.map(item => item.id)])];
    const profileRefs = userIds.map(uid => db.collection('users').doc(uid));
    const [profiles, notificationSnapshots] = await Promise.all([
      Promise.all(profileRefs.map(ref => transaction.get(ref))),
      Promise.all(userIds.map(uid => transaction.get(
        db.collection('users').doc(uid).collection('notifications').where('groupId', '==', circleId),
      ))),
    ]);
    const notificationCount = notificationSnapshots.reduce((total, snapshot) => total + snapshot.size, 0);
    if (memberships.size + invites.size + requests.size + devices.size + profiles.length + notificationCount + 1 > 450) {
      throw new HttpsError('failed-precondition', 'This Circle requires a larger server cleanup job. No data was changed.');
    }
    const now = FieldValue.serverTimestamp();
    transaction.update(groupRef, {
      status: 'deleted', deletedAt: now, deletedBy: userId,
      memberIds: [], roles: {}, emergencyRecipientIds: [], updatedAt: now,
    });
    memberships.docs.forEach(member => {
      transaction.update(member.ref, {status: 'removed', endedAt: now, endedBy: userId, updatedAt: now});
    });
    invites.docs.forEach(invite => transaction.update(invite.ref, {
      status: 'revoked', revokedAt: now, revokedBy: userId, updatedAt: now,
    }));
    requests.docs.forEach(item => transaction.update(item.ref, {
      status: 'rejected', reviewedAt: now, reviewedBy: userId, updatedAt: now,
    }));
    devices.docs.forEach(device => transaction.update(device.ref, {
      pairingStatus: 'unpaired', removedAt: now, removedBy: userId, updatedAt: now,
    }));
    notificationSnapshots.forEach(snapshot => {
      snapshot.docs.forEach(notification => transaction.delete(notification.ref));
    });
    profiles.forEach((profile, index) => {
      if (profile.exists) transaction.set(profileRefs[index], profileCircleCleanup(circleId, profile.data()), {merge: true});
    });
  });
  return {circleId};
});

// Added Users are owner-private relationships, never implicit Circle seats.
function authenticated(request: {auth?: {uid: string}}): string {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in again.');
  return request.auth.uid;
}
function safeId(value: unknown): string {
  const id = String(value ?? '');
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id)) throw new HttpsError('invalid-argument', 'Invalid identity.');
  return id;
}
function recipient(request: {auth?: {uid: string; token: Record<string, unknown>}}, invite: admin.firestore.DocumentData): void {
  const email = String(request.auth?.token.email ?? '').toLowerCase();
  if (!request.auth || request.auth.token.email_verified !== true || email !== invite.email ||
      (invite.targetUserId && invite.targetUserId !== request.auth.uid)) {
    throw new HttpsError('permission-denied', 'Sign in with the verified invited email address.');
  }
}
function queueEvent(tx: admin.firestore.Transaction, id: string, targetUserId: string, type: string, title: string, body: string, groupId = '') {
  tx.set(db.collection('safetyEvents').doc(id), {targetUserId, type, title, body, groupId, createdAt: FieldValue.serverTimestamp(), deliveryStatus: 'pending'});
}
function queueInvitation(tx: admin.firestore.Transaction, id: string, data: admin.firestore.DocumentData) {
  tx.create(db.collection('invitationDeliveries').doc(id), {...data, invitationId: id,
    emailStatus: 'pending', pushStatus: 'pending', createdAt: FieldValue.serverTimestamp()});
}
export const inviteSafetyUser = onCall(async request => {
  const ownerId = authenticated(request);
  const email = String(request.data?.email ?? '').trim().toLowerCase();
  const name = String(request.data?.name ?? '').trim();
  const phone = String(request.data?.phone ?? '');
  const relationship = String(request.data?.relationship ?? '').trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254 || name.length < 2 || name.length > 60 ||
      !/^\+[1-9]\d{6,14}$/.test(phone) || !relationship || relationship.length > 60) {
    throw new HttpsError('invalid-argument', 'Enter a valid name, email, mobile number and relationship.');
  }
  if (email === String(request.auth?.token.email ?? '').toLowerCase()) throw new HttpsError('invalid-argument', 'You cannot invite yourself.');
  let targetUserId: string | null = null;
  try { targetUserId = (await admin.auth().getUserByEmail(email)).uid; }
  catch (error) { if ((error as {code?: string}).code !== 'auth/user-not-found') throw error; }
  const id = inviteCode();
  await db.runTransaction(async tx => {
    const owner = db.collection('users').doc(ownerId);
    const [profile, relationships] = await Promise.all([tx.get(owner), tx.get(owner.collection('safetyUsers'))]);
    const active = relationships.docs.filter(doc => activeSafetySlot(doc.data()));
    if (active.some(doc => doc.data().email === email)) throw new HttpsError('already-exists', 'This user already has an active relationship or invitation.');
    if (!isPremium(profile.data()) && active.length >= 5) throw new HttpsError('resource-exhausted', 'Your Free Plan allows 5 Added Users, including pending invitations.');
    const now = FieldValue.serverTimestamp();
    const expiresAt = Timestamp.fromMillis(Date.now() + 7 * 86400000);
    const senderName = String(profile.data()?.name ?? 'A user');
    tx.create(owner.collection('safetyUsers').doc(id), {ownerId, targetUserId, email, name, phone, relationship, invitationId: id, status: 'pending', expiresAt, createdAt: now});
    tx.create(db.collection('safetyInvites').doc(id), {ownerId, targetUserId, email, senderName, senderPhotoUrl: profile.data()?.photoUrl ?? null, status: 'pending', expiresAt, createdAt: now});
    // Profile write serializes capacity decisions, including concurrent new invites.
    tx.set(owner, {safetyUpdatedAt: now}, {merge: true});
    queueInvitation(tx, id, {ownerId, targetUserId, email, senderName, type: 'safety_invite'});
  });
  return {invitationId: id, emailStatus: process.env.INVITATION_EMAIL_ENDPOINT && process.env.INVITATION_EMAIL_TOKEN && process.env.INVITATION_LINK_BASE ? 'queued' : 'configuration-required'};
});
export const respondSafetyInvite = onCall(async request => {
  const uid = authenticated(request), id = safeId(request.data?.invitationId);
  const accept = request.data?.accept === true;
  await db.runTransaction(async tx => {
    const ref = db.collection('safetyInvites').doc(id);
    const invite = await tx.get(ref), data = invite.data();
    if (!data) throw new HttpsError('not-found', 'Invitation unavailable.');
    recipient(request, data);
    const relationship = db.collection('users').doc(data.ownerId).collection('safetyUsers').doc(id);
    const saved = await tx.get(relationship);
    const targetProfile = await tx.get(db.collection('users').doc(uid));
    if (data.status === (accept ? 'accepted' : 'declined')) return;
    if (data.status !== 'pending' || data.expiresAt.toMillis() <= Date.now() || !saved.exists) throw new HttpsError('failed-precondition', 'Invitation is no longer active.');
    const now = FieldValue.serverTimestamp();
    tx.update(ref, {status: accept ? 'accepted' : 'declined', targetUserId: uid, respondedAt: now});
    if (accept) tx.update(relationship, {status: 'connected', targetUserId: uid, photoUrl: targetProfile.data()?.photoUrl ?? null, acceptedAt: now, notificationPreferences: defaultSafetyPreferences});
    else tx.delete(relationship);
    tx.set(db.collection('users').doc(data.ownerId), {safetyUpdatedAt: now}, {merge: true});
  });
  return {status: accept ? 'connected' : 'declined'};
});
export const updateSafetyPreferences = onCall(async request => {
  const uid = authenticated(request), id = safeId(request.data?.relationshipId);
  await db.runTransaction(async tx => {
    const ref = db.collection('users').doc(uid).collection('safetyUsers').doc(id);
    const [relationship, owner] = await Promise.all([tx.get(ref), tx.get(db.collection('users').doc(uid))]);
    if (relationship.data()?.ownerId !== uid || relationship.data()?.status !== 'connected') throw new HttpsError('permission-denied', 'Active owned relationship required.');
    if (!validSafetyPreferences(request.data?.preferences, isPremium(owner.data()))) throw new HttpsError('permission-denied', 'Advanced notifications require Premium.');
    tx.update(ref, {notificationPreferences: request.data.preferences, updatedAt: FieldValue.serverTimestamp()});
  });
  return {updated: true};
});
export const removeSafetyUser = onCall(async request => {
  const ownerId = authenticated(request), id = safeId(request.data?.relationshipId);
  await db.runTransaction(async tx => {
    const owner = db.collection('users').doc(ownerId), ref = owner.collection('safetyUsers').doc(id);
    const relationship = await tx.get(ref), data = relationship.data();
    if (!data) {
      const previous = await tx.get(db.collection('safetyInvites').doc(id));
      if (previous.data()?.ownerId === ownerId && previous.data()?.status === 'revoked') return;
      throw new HttpsError('permission-denied', 'Only the relationship owner can remove this user.');
    }
    if (data.ownerId !== ownerId) throw new HttpsError('permission-denied', 'Only the relationship owner can remove this user.');
    const target = data.targetUserId as string | null;
    const [profile, groups, personal, direct, ownedRelationships] = await Promise.all([
      tx.get(owner), tx.get(db.collection('groups').where('ownerId', '==', ownerId)),
      tx.get(db.collection('safetyInvites').where('ownerId', '==', ownerId)),
      tx.get(db.collection('circleInvites').where('createdBy', '==', ownerId)),
      tx.get(owner.collection('safetyUsers')),
    ]);
    const affected = groups.docs.filter(group => group.data().status === 'active' && target && strings(group.data().memberIds).includes(target));
    const details = await Promise.all(affected.map(async group => ({group,
      devices: await tx.get(group.ref.collection('devices')),
      requests: await tx.get(group.ref.collection('joinRequests')),
    })));
    const otherRequests = target ? await Promise.all(groups.docs
      .filter(group => group.data().status === 'active' && !affected.some(item => item.id === group.id))
      .map(group => tx.get(group.ref.collection('joinRequests').doc(target)))) : [];
    const targetRef = target ? db.collection('users').doc(target) : null;
    const targetProfile = targetRef ? await tx.get(targetRef) : null;
    const cancelledPersonal = personal.docs.filter(doc => doc.data().email === data.email && doc.data().status === 'pending');
    const relatedRows = ownedRelationships.docs.filter(doc => doc.id !== id && (doc.data().email === data.email || (target && doc.data().targetUserId === target)));
    const cancelledDirect = direct.docs.filter(doc =>
      groups.docs.some(group => group.id === doc.data().circleId && group.data().ownerId === ownerId) &&
      ((target && (doc.data().targetUserId === target || doc.data().reservedBy === target)) || doc.data().email === data.email) && doc.data().status === 'active');
    const writes = 5 + relatedRows.length + otherRequests.length + cancelledPersonal.length + cancelledDirect.length + details.reduce((sum, item) => sum + 5 + item.devices.size + item.requests.size, 0);
    if (writes > 440) throw new HttpsError('resource-exhausted', 'This removal requires administrator-assisted cleanup. No data was changed.');
    const now = FieldValue.serverTimestamp();
    tx.delete(ref); // Includes all owner-private contact metadata and preferences.
    for (const row of relatedRows) tx.delete(row.ref);
    tx.set(owner, {safetyUpdatedAt: now}, {merge: true});
    for (const doc of cancelledPersonal) tx.update(doc.ref, {status: 'revoked', revokedAt: now});
    // Accepted invite retains only lifecycle/audit identity, not owner contact metadata.
    tx.set(db.collection('safetyInvites').doc(id), {status: 'revoked', revokedAt: now}, {merge: true});
    for (const doc of cancelledDirect) tx.update(doc.ref, {status: 'revoked', revokedAt: now});
    for (const pending of otherRequests) if (pending.data()?.status === 'pending') tx.update(pending.ref, {status: 'cancelled', updatedAt: now});
    for (const {group, devices, requests} of details) {
      const rolesMap = roles(group.data().roles); delete rolesMap[target!];
      tx.update(group.ref, {memberIds: FieldValue.arrayRemove(target), roles: rolesMap, emergencyRecipientIds: FieldValue.arrayRemove(target), updatedAt: now});
      tx.set(group.ref.collection('memberships').doc(target!), {status: 'removed', endedBy: ownerId, endedAt: now}, {merge: true});
      tx.delete(group.ref.collection('publicMembers').doc(target!));
      for (const device of devices.docs) if (device.data().ownerUserId === target) tx.update(device.ref, {status: 'unpaired', updatedAt: now});
      for (const pending of requests.docs) if (pending.id === target && pending.data().status === 'pending') tx.update(pending.ref, {status: 'cancelled', updatedAt: now});
      queueEvent(tx, `${id}_${group.id}_removed`, target!, 'circle_removed', 'Circle membership removed', `You were removed from ${group.data().name ?? 'a Circle'}.`, group.id);
    }
    if (targetRef && targetProfile?.exists && (affected.length || cancelledDirect.length || otherRequests.length)) {
      const removed = affected.map(group => group.id);
      const update: Record<string, unknown> = {updatedAt: now};
      if (removed.length) {
        update.circleIds = FieldValue.arrayRemove(...removed);
        update.joinedCircleIds = FieldValue.arrayRemove(...removed);
      }
      if (removed.includes(targetProfile.data()?.activeCircleId)) update.activeCircleId = FieldValue.delete();
      if (groups.docs.some(group => group.id === targetProfile.data()?.pendingJoinCircleId)) { update.pendingJoinCircleId = FieldValue.delete(); update.pendingJoinInviteId = FieldValue.delete(); }
      tx.update(targetRef, update);
    }
    if (target && data.status === 'connected') queueEvent(tx, `${id}_removed`, target, 'safety_removed', 'User relationship removed', `${profile.data()?.name ?? 'A user'} removed you from their Users List.`);
  });
  return {removed: true};
});
export const deliverSafetyEvent = onDocumentCreated('safetyEvents/{eventId}', async event => {
  const data = event.data?.data(); if (!data) return;
  const history = db.collection('users').doc(data.targetUserId).collection('notifications').doc(event.params.eventId);
  const eligible = await db.runTransaction(async tx => {
    const current = await tx.get(event.data!.ref);
    if (!current.exists || current.data()?.deliveryStatus !== 'pending') return false;
    if (data.relationshipPath) {
      const [relationship, owner] = await Promise.all([tx.get(db.doc(data.relationshipPath)), tx.get(db.doc(`users/${data.targetUserId}`))]);
      const live = relationship.data();
      if (live?.status !== 'connected' || live.targetUserId !== data.monitoredUserId || live.notificationPreferences?.[data.category] !== true || (data.category !== 'emergencyAlerts' && !isPremium(owner.data()))) {
        tx.update(event.data!.ref, {deliveryStatus: 'cancelled'}); return false;
      }
    }
    tx.set(history, {title: data.title, body: data.body, type: data.type, groupId: data.groupId, createdAt: data.createdAt, isRead: false});
    tx.update(event.data!.ref, {deliveryStatus: 'processing'});
    return true;
  });
  if (!eligible) return;
  try {
    const sent = await sendPushNotification(data.targetUserId, data.groupId, data.title, data.body, data.type);
    await updateDelivery(event.data!.ref, {deliveryStatus: sent ? 'provider-accepted' : 'no-active-device'});
  } catch (error) { await updateDelivery(event.data!.ref, {deliveryStatus: 'failed', failure: String(error)}); }
});
export const deliverInvitation = onDocumentCreated('invitationDeliveries/{invitationId}', async event => {
  const data = event.data?.data(); if (!data) return;
  const ref = event.data!.ref;
  const endpoint = process.env.INVITATION_EMAIL_ENDPOINT;
  const base = process.env.INVITATION_LINK_BASE;
  if (!endpoint || !base || !process.env.INVITATION_EMAIL_TOKEN) await updateDelivery(ref, {emailStatus: 'configuration-required'});
  else {
    try {
      if (!endpoint.startsWith('https://') || !base.startsWith('https://')) throw new Error('HTTPS configuration required');
      const response = await fetch(endpoint, {method: 'POST', signal: AbortSignal.timeout(15000), headers: {'Content-Type': 'application/json', Authorization: `Bearer ${process.env.INVITATION_EMAIL_TOKEN}`, 'Idempotency-Key': event.params.invitationId},
        body: JSON.stringify({to: data.email, subject: `${data.senderName} invited you${data.circleName ? ` to ${data.circleName}` : ' to connect'}`,
          text: `${data.senderName} invited you ${data.circleName ? `to join ${data.circleName}` : 'as a Safety User'}. Open ${base}?${data.type === 'safety_invite' ? 'safetyInvite' : 'code'}=${event.params.invitationId}. Install the Family Emergency app if needed, then sign in with this email address and accept the request.`})});
      if (!response.ok) throw new Error(`Email provider returned ${response.status}`);
      await updateDelivery(ref, {emailStatus: 'provider-accepted'});
    } catch (error) { await updateDelivery(ref, {emailStatus: 'failed', emailError: String(error)}); }
  }
  if (!data.targetUserId) { await updateDelivery(ref, {pushStatus: 'no-account'}); return; }
  try {
    await db.collection('users').doc(data.targetUserId).collection('notifications').doc(event.params.invitationId).set({type: data.type, title: 'New invitation', body: `${data.senderName} sent you ${data.circleName ? `an invitation to ${data.circleName}` : 'a Safety User request'}.`, groupId: '', isRead: false, createdAt: FieldValue.serverTimestamp()});
    const devices = await db.collection('users').doc(data.targetUserId).collection('devices').where('status', '==', 'active').where('notificationsEnabled', '==', true).get();
    const capable = devices.docs.some(doc => typeof doc.data().fcmToken === 'string' && doc.data().fcmToken.length > 0);
    if (capable) await sendPushNotification(data.targetUserId, '', 'New invitation', `${data.senderName} sent you an invitation.`, data.type);
    await updateDelivery(ref, {pushStatus: capable ? 'provider-accepted' : 'no-active-device'});
  } catch (error) { await updateDelivery(ref, {pushStatus: 'failed', pushError: String(error)}); }
});
export const respondDirectCircleInvite = onCall(async request => {
  const uid = authenticated(request), id = safeId(request.data?.invitationId);
  await db.runTransaction(async tx => {
    const inviteRef = db.collection('circleInvites').doc(id);
    const invite = await tx.get(inviteRef), data = invite.data();
    if (!data) throw new HttpsError('not-found', 'Invitation unavailable.');
    recipient(request, data);
    if (data.status === 'consumed' && data.targetUserId === uid && request.data?.accept === true) return;
    if (data.status !== 'active' || data.expiresAt.toMillis() <= Date.now()) throw new HttpsError('failed-precondition', 'Invitation no longer active.');
    const groupRef = db.collection('groups').doc(data.circleId);
    const [group, target, joined] = await Promise.all([tx.get(groupRef), tx.get(db.collection('users').doc(uid)), activeCirclesFor(tx, uid)]);
    const groupData = ensureActiveGroup(group);
    const owner = await tx.get(db.collection('users').doc(String(groupData.ownerId)));
    if (data.createdBy !== groupData.ownerId) throw new HttpsError('permission-denied', 'Only the Circle owner may directly invite users.');
    const now = FieldValue.serverTimestamp();
    if (request.data?.accept !== true) { tx.update(inviteRef, {status: 'declined', respondedAt: now}); return; }
    if (strings(groupData.memberIds).includes(uid)) throw new HttpsError('already-exists', 'You already belong to this Circle.');
    if (!isPremium(target.data()) && joined.docs.filter(doc => doc.data().ownerId !== uid).length >= FREE_MAX_JOINED) throw new HttpsError('resource-exhausted', 'Your Free Plan allows 1 joined Circle.');
    if (strings(groupData.memberIds).length >= maxMembers(owner.data())) throw new HttpsError('resource-exhausted', 'Circle is full.');
    tx.update(groupRef, {memberIds: FieldValue.arrayUnion(uid), roles: {...roles(groupData.roles), [uid]: 'adult'}, updatedAt: now});
    tx.set(groupRef.collection('memberships').doc(uid), {userId: uid, displayName: target.data()?.name ?? '', photoUrl: target.data()?.photoUrl ?? null, circleRole: 'adult', status: 'active', joinedAt: now, updatedAt: now});
    tx.set(db.collection('users').doc(uid), {circleIds: FieldValue.arrayUnion(data.circleId), joinedCircleIds: FieldValue.arrayUnion(data.circleId), activeCircleId: data.circleId, updatedAt: now}, {merge: true});
    tx.update(inviteRef, {status: 'consumed', useCount: 1, consumedBy: uid, consumedAt: now});
  });
  return {accepted: request.data?.accept === true};
});
// Never enabled by a client flag or an email comparison in production.
export const setTestPlan = onCall(async request => {
  const uid = authenticated(request);
  if (process.env.FUNCTIONS_EMULATOR !== 'true' || process.env.ENABLE_TEST_ENTITLEMENTS !== 'true' ||
      request.auth?.token.email !== 'nihalafaq@gmail.com' || request.auth.token.email_verified !== true) {
    throw new HttpsError('permission-denied', 'Test plans are available only in the explicitly enabled local emulator.');
  }
  if (!['free', 'premium'].includes(request.data?.mode)) throw new HttpsError('invalid-argument', 'Choose Free or Premium test mode.');
  await db.collection('users').doc(uid).set({planTier: request.data.mode, subscriptionStatus: request.data.mode === 'premium' ? 'active' : 'inactive'}, {merge: true});
  return {mode: request.data.mode};
});
export const publishCircleMember = onDocumentUpdated('groups/{groupId}/memberships/{userId}', async event => {
  await publishMember(event.params.groupId, event.params.userId);
});
export const publishNewCircleMember = onDocumentCreated('groups/{groupId}/memberships/{userId}', async event => {
  await publishMember(event.params.groupId, event.params.userId);
});
async function publishMember(groupId: string, userId: string) {
  await db.runTransaction(async tx => {
    const privateRef = db.collection('groups').doc(groupId).collection('memberships').doc(userId);
    const snapshot = await tx.get(privateRef), data = snapshot.data();
    const publicRef = db.collection('groups').doc(groupId).collection('publicMembers').doc(userId);
    if (!data || data.status !== 'active') { tx.delete(publicRef); return; }
    tx.set(publicRef, {userId, displayName: data.displayName ?? '', photoUrl: data.photoUrl ?? null, circleRole: data.circleRole, status: data.status, joinedAt: data.joinedAt ?? null});
  });
}
async function updateDelivery(ref: admin.firestore.DocumentReference, data: admin.firestore.DocumentData) {
  await db.runTransaction(async tx => { if ((await tx.get(ref)).exists) tx.update(ref, data); });
}
// Shared per-target delivery boundary. Signals come from trusted event handlers,
// never from clients, and queued alerts recheck live relationship + entitlement.
async function safetySignal(targetId: string, category: string, eventId: string, title: string, body: string, exclude: string[] = []) {
  const relationships = await db.collectionGroup('safetyUsers').where('targetUserId', '==', targetId).where('status', '==', 'connected').get();
  await Promise.all(relationships.docs.map(async relationship => {
    const data = relationship.data();
    if (exclude.includes(data.ownerId)) return;
    const ref = db.collection('safetyEvents').doc(`${relationship.id}_${eventId}`);
    await db.runTransaction(async tx => {
      const [current, owner, previous] = await Promise.all([tx.get(relationship.ref), tx.get(db.doc(`users/${data.ownerId}`)), tx.get(ref)]);
      const latest = current.data();
      if (previous.exists || latest?.status !== 'connected' || latest.targetUserId !== targetId || latest.notificationPreferences?.[category] !== true ||
          (category !== 'emergencyAlerts' && !isPremium(owner.data()))) return;
      tx.create(ref, {targetUserId: data.ownerId, monitoredUserId: targetId, relationshipPath: relationship.ref.path,
        category, type: category === 'emergencyAlerts' ? 'emergency_safety' : 'safety_activity', title, body, groupId: '', createdAt: FieldValue.serverTimestamp(), deliveryStatus: 'pending'});
    });
  }));
}
export const notifySafetyCheckIn = onDocumentUpdated('users/{userId}', async event => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!after?.lastDailyCheckInAt || before?.lastDailyCheckInLocalDate === after.lastDailyCheckInLocalDate) return;
  await safetySignal(event.params.userId, 'missedCheckInAlerts', `checkin_${after.lastDailyCheckInLocalDate}`, 'Safety User check-in', 'Your Safety User checked in.');
});
export const notifySafetyLocation = onDocumentCreated('groups/{groupId}/locationEvents/{eventId}', async event => {
  const data = event.data?.data(); if (!data?.userId) return;
  await safetySignal(data.userId, 'locationSharing', `location_${event.params.eventId}`, 'Location activity', 'Your Safety User shared location activity.');
});
export const notifySafetyScreenTime = onDocumentUpdated('users/{userId}/devices/{deviceId}/screenTimeDaily/{date}', async event => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!after || Number(after.totalTimeMs) < 4 * 3600000 || Number(before?.totalTimeMs) >= 4 * 3600000) return;
  await safetySignal(event.params.userId, 'screenTimeAlerts', `screen_${event.params.date}`, 'Screen Time update', 'Your Safety User reached four hours of Screen Time today.');
});
export const notifyInitialSafetyScreenTime = onDocumentCreated('users/{userId}/devices/{deviceId}/screenTimeDaily/{date}', async event => {
  const data = event.data?.data();
  if (!data || Number(data.totalTimeMs) < 4 * 3600000) return;
  await safetySignal(event.params.userId, 'screenTimeAlerts', `screen_${event.params.date}`, 'Screen Time update', 'Your Safety User reached four hours of Screen Time today.');
});
export const notifySafetyBattery = onDocumentUpdated('users/{userId}/devices/{deviceId}', async event => {
  const before = event.data?.before.data(), after = event.data?.after.data();
  if (!after || after.status !== 'active' || typeof after.batteryLevel !== 'number' || after.batteryLevel > 20 || (typeof before?.batteryLevel === 'number' && before.batteryLevel <= 20)) return;
  await safetySignal(event.params.userId, 'batteryAlerts', `battery_${event.id}`, 'Low battery', 'Your Safety User has a device with low battery.');
});
export const notifySafetyOffline = onSchedule('every 15 minutes', async () => {
  const query = db.collectionGroup('devices').where('status', '==', 'active')
    .where('lastSeenAt', '<', Timestamp.fromMillis(Date.now() - 60 * 60000)).orderBy('lastSeenAt').limit(200);
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    const page = await (cursor ? query.startAfter(cursor) : query).get();
    if (page.empty) break;
    for (const device of page.docs) {
      const parts = device.ref.path.split('/');
      if (parts.length !== 4 || parts[0] !== 'users') continue;
      await safetySignal(parts[1], 'offlineAlerts', `offline_${device.id}_${device.data().lastSeenAt.toMillis()}`, 'Device offline', 'Your Safety User has a device that has not checked in for over an hour.');
    }
    cursor = page.docs[page.docs.length - 1];
  }
});
export const listCircleSafetyCandidates = onCall(async request => {
  const uid = authenticated(request), circleId = requireCircleId(request.data);
  const group = await db.doc(`groups/${circleId}`).get();
  const groupData = ensureActiveGroup(group);
  if (groupData.ownerId !== uid) throw new HttpsError('permission-denied', 'Only the Circle owner can invite Added Users.');
  const [owner, users, invites, requests] = await Promise.all([
    db.doc(`users/${uid}`).get(), db.collection(`users/${uid}/safetyUsers`).get(),
    db.collection('circleInvites').where('circleId', '==', circleId).where('status', '==', 'active').get(),
    group.ref.collection('joinRequests').where('status', '==', 'pending').get(),
  ]);
  const active = invites.docs.filter(doc => doc.data().expiresAt.toMillis() > Date.now());
  const full = strings(groupData.memberIds).length + active.length >= maxMembers(owner.data());
  const candidates = await Promise.all(users.docs.filter(doc => doc.data().status === 'connected').map(async doc => {
    const data = doc.data();
    const [profile, circles] = await Promise.all([db.doc(`users/${data.targetUserId}`).get(), db.collection('groups').where('memberIds', 'array-contains', data.targetUserId).where('status', '==', 'active').get()]);
    const reason = strings(groupData.memberIds).includes(data.targetUserId) ? 'Already a member' :
      active.some(invite => invite.data().targetUserId === data.targetUserId) || requests.docs.some(item => item.id === data.targetUserId) ? 'Invitation already pending' :
      full ? 'Circle is full' : !isPremium(profile.data()) && circles.docs.filter(item => item.data().ownerId !== data.targetUserId).length >= FREE_MAX_JOINED ? 'Joined Circle limit reached' : null;
    return {id: doc.id, name: data.name, eligible: reason === null, reason};
  }));
  return {candidates};
});
