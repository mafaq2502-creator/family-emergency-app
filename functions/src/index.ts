import * as admin from 'firebase-admin';
import {FieldValue} from 'firebase-admin/firestore';
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
  const recipientIds: string[] = group.data()?.emergencyRecipientIds ?? [];
  const recipients = recipientIds.filter(id => id !== emergency.senderId);
  await Promise.all(recipients.map(async userId => deliverNotification(userId, event.params.groupId, 'Emergency SOS', `${emergency.senderName ?? 'A member'} needs help. Tap to acknowledge.`, 'emergency', event.params.emergencyId)));
});

export const notifyEmergencyAcknowledgement = onDocumentUpdated('groups/{groupId}/emergencies/{emergencyId}', async event => {
  const before = event.data?.before.data(); const after = event.data?.after.data();
  if (!before || !after || before.status === after.status || after.status !== 'acknowledged') return;
  await deliverNotification(after.senderId, event.params.groupId, 'SOS acknowledged', `${after.acknowledgedByName ?? 'A group member'} acknowledged your emergency.`, 'emergencyAcknowledged', event.params.emergencyId);
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
