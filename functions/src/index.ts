import * as admin from 'firebase-admin';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';

admin.initializeApp();
const db = admin.firestore();

async function writeNotification(userId: string, groupId: string, title: string, body: string, type: string, emergencyId?: string) {
  await db.collection('users').doc(userId).collection('notifications').add({groupId, title, body, type, emergencyId: emergencyId ?? null, isRead: false, createdAt: admin.firestore.FieldValue.serverTimestamp()});
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
