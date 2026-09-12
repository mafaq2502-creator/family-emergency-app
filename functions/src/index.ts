import * as admin from 'firebase-admin';
import {randomBytes} from 'node:crypto';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

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
  if (tokens.length === 0) return;
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
    transaction.create(inviteRef, {
      circleId, circleName: groupSnapshot.data()?.name, createdBy: userId,
      createdAt: now, expiresAt: Timestamp.fromMillis(Date.now() + 7 * 86400000),
      status: 'active', inviteType: 'singleUse', maxUses: 1, useCount: 0,
      requiresApproval: true, circleRole,
    });
  });
  const group = await db.collection('groups').doc(circleId).get();
  return {id: code, circleId, circleName: String(group.data()?.name ?? 'Family Circle'),
    createdBy: userId, expiresAtMillis: Date.now() + 7 * 86400000, status: 'active', maxUses: 1,
    useCount: 0, requiresApproval: true, circleRole};
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
