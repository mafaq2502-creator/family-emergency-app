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
  return update;
}

async function writeNotification(userId: string, groupId: string, title: string, body: string, type: string, emergencyId?: string) {
  await db.collection('users').doc(userId).collection('notifications').add({groupId, title, body, type, emergencyId: emergencyId ?? null, isRead: false, createdAt: FieldValue.serverTimestamp()});
}

export const sendEmergencyToRecipients = onDocumentCreated('groups/{groupId}/emergencies/{emergencyId}', async event => {
  const emergency = event.data?.data(); if (!emergency) return;
  const group = await db.collection('groups').doc(event.params.groupId).get();
  const recipientIds: string[] = group.data()?.emergencyRecipientIds ?? [];
  const recipients = recipientIds.filter(id => id !== emergency.senderId);
  await Promise.all(recipients.map(async userId => writeNotification(userId, event.params.groupId, 'Emergency SOS', `${emergency.senderName ?? 'A member'} needs help. Tap to acknowledge.`, 'emergency', event.params.emergencyId)));
  // FCM tokens are stored under users/{uid}/devices. Add firebase_messaging delivery here after client token registration is enabled.
});

export const notifyEmergencyAcknowledgement = onDocumentUpdated('groups/{groupId}/emergencies/{emergencyId}', async event => {
  const before = event.data?.before.data(); const after = event.data?.after.data();
  if (!before || !after || before.status === after.status || after.status !== 'acknowledged') return;
  await writeNotification(after.senderId, event.params.groupId, 'SOS acknowledged', `${after.acknowledgedByName ?? 'A group member'} acknowledged your emergency.`, 'emergencyAcknowledged', event.params.emergencyId);
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
    const profileRefs = memberships.docs.map(member => db.collection('users').doc(member.id));
    const profiles = await Promise.all(profileRefs.map(ref => transaction.get(ref)));
    const now = FieldValue.serverTimestamp();
    transaction.update(groupRef, {
      status: 'deleted', deletedAt: now, deletedBy: userId,
      memberIds: [], roles: {}, emergencyRecipientIds: [], updatedAt: now,
    });
    memberships.docs.forEach(member => {
      transaction.update(member.ref, {status: 'removed', endedAt: now, endedBy: userId, updatedAt: now});
    });
    profiles.forEach((profile, index) => {
      if (profile.exists) transaction.set(profileRefs[index], profileCircleCleanup(circleId, profile.data()), {merge: true});
    });
  });
  return {circleId};
});
