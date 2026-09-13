const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword} = require('firebase/auth');
const {getFunctions, connectFunctionsEmulator, httpsCallable} = require('firebase/functions');
const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({projectId: 'demo-alivecircle'});
const db = admin.firestore();
const apps = [];
let sequence = 0;
async function actor(label) {
  const email = `${label}-${++sequence}-${Date.now()}@example.test`;
  const app = initializeApp({projectId: 'demo-alivecircle', apiKey: 'demo-key'}, email);
  apps.push(app);
  const auth = getAuth(app); connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  const {user} = await createUserWithEmailAndPassword(auth, email, 'Testing-pass-123!');
  await admin.auth().updateUser(user.uid, {emailVerified: true});
  await user.getIdToken(true);
  const functions = getFunctions(app); connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  await db.doc(`users/${user.uid}`).set({name: label, email, planTier: 'free', subscriptionStatus: 'inactive'});
  return {uid: user.uid, email, call: async (name, data) => (await httpsCallable(functions, name)(data)).data};
}
async function invite(owner, target) {
  return owner.call('inviteSafetyUser', {name: 'Safety Person', email: target.email, phone: '+923001234567', relationship: 'Brother'});
}
async function connected(owner, target) {
  const result = await invite(owner, target);
  await target.call('respondSafetyInvite', {invitationId: result.invitationId, accept: true});
  return result.invitationId;
}
async function circle(id, owner, target) {
  await db.doc(`groups/${id}`).set({ownerId: owner.uid, name: id, status: 'active', memberIds: [owner.uid, target.uid], roles: {[owner.uid]: 'owner', [target.uid]: 'adult'}, emergencyRecipientIds: [target.uid]});
  for (const user of [owner, target]) await db.doc(`groups/${id}/memberships/${user.uid}`).set({userId: user.uid, displayName: 'Member', circleRole: user.uid === owner.uid ? 'owner' : 'adult', status: 'active'});
}
before(() => { assert.ok(process.env.FIRESTORE_EMULATOR_HOST); assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST); });
beforeEach(async () => {
  const response = await fetch('http://127.0.0.1:8080/emulator/v1/projects/demo-alivecircle/databases/(default)/documents', {method: 'DELETE'});
  assert.ok(response.ok);
});
after(async () => { await Promise.all(apps.map(deleteApp)); await admin.app().delete(); });
test('personal acceptance is verified, private, connected, idempotent and not a Circle seat', async () => {
  const owner = await actor('owner'), target = await actor('target'), other = await actor('other');
  const {invitationId: id, emailStatus} = await invite(owner, target);
  assert.equal(emailStatus, 'configuration-required');
  await assert.rejects(other.call('respondSafetyInvite', {invitationId: id, accept: true}), /verified invited email/);
  await target.call('respondSafetyInvite', {invitationId: id, accept: true});
  await target.call('respondSafetyInvite', {invitationId: id, accept: true});
  const data = (await db.doc(`users/${owner.uid}/safetyUsers/${id}`).get()).data();
  assert.equal(data.status, 'connected');
  assert.equal(data.notificationPreferences.emergencyAlerts, true);
  assert.equal(Object.values(data.notificationPreferences).filter(Boolean).length, 1);
  assert.equal((await db.collection('groups').get()).size, 0);
});
test('parallel invitations cannot exceed five reserved slots', async () => {
  const owner = await actor('owner');
  const results = await Promise.allSettled(Array.from({length: 6}, (_, i) => invite(owner, {email: `unregistered-${i}@example.test`})));
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 5);
  assert.equal((await db.collection(`users/${owner.uid}/safetyUsers`).get()).size, 5);
});
test('decline, expiry and revoke release slots and expired acceptance fails', async () => {
  const owner = await actor('owner'), target = await actor('target');
  const first = await invite(owner, target);
  await target.call('respondSafetyInvite', {invitationId: first.invitationId, accept: false});
  assert.equal((await db.doc(`users/${owner.uid}/safetyUsers/${first.invitationId}`).get()).exists, false);
  const second = await invite(owner, target);
  const expired = admin.firestore.Timestamp.fromMillis(0);
  await db.doc(`safetyInvites/${second.invitationId}`).update({expiresAt: expired});
  await db.doc(`users/${owner.uid}/safetyUsers/${second.invitationId}`).update({expiresAt: expired});
  await assert.rejects(target.call('respondSafetyInvite', {invitationId: second.invitationId, accept: true}));
  const third = await invite(owner, target);
  await owner.call('removeSafetyUser', {relationshipId: third.invitationId});
  assert.equal((await db.doc(`safetyInvites/${third.invitationId}`).get()).data().status, 'revoked');
});
test('removal cleans only owned Circles, private preferences, pending invites and keeps account', async () => {
  const owner = await actor('owner'), target = await actor('target'), other = await actor('other');
  const id = await connected(owner, target);
  await db.doc(`users/${owner.uid}`).update({planTier: 'premium', subscriptionStatus: 'active'});
  await circle('owned-a', owner, target); await circle('owned-b', owner, target); await circle('third-party', other, target);
  await db.doc(`users/${target.uid}`).update({circleIds: ['owned-a', 'owned-b', 'third-party'], joinedCircleIds: ['owned-a', 'owned-b', 'third-party'], activeCircleId: 'owned-a'});
  await db.doc('circleInvites/pending-target').set({circleId: 'owned-a', createdBy: owner.uid, targetUserId: target.uid, status: 'active', email: target.email});
  await assert.rejects(other.call('removeSafetyUser', {relationshipId: id}));
  assert.equal((await db.doc(`users/${owner.uid}/safetyUsers/${id}`).get()).exists, true);
  await owner.call('removeSafetyUser', {relationshipId: id});
  await owner.call('removeSafetyUser', {relationshipId: id});
  assert.equal((await db.doc(`users/${owner.uid}/safetyUsers/${id}`).get()).exists, false);
  for (const name of ['owned-a', 'owned-b']) assert.equal((await db.doc(`groups/${name}`).get()).data().memberIds.includes(target.uid), false);
  assert.equal((await db.doc('groups/third-party').get()).data().memberIds.includes(target.uid), true);
  assert.deepEqual((await db.doc(`users/${target.uid}`).get()).data().circleIds, ['third-party']);
  assert.ok(await admin.auth().getUser(target.uid));
  assert.equal((await db.doc('circleInvites/pending-target').get()).data().status, 'revoked');
  const events = await db.collection('safetyEvents').get();
  assert.equal(events.docs.filter(doc => doc.data().targetUserId === target.uid).length, 3);
  await assert.rejects(owner.call('updateSafetyPreferences', {relationshipId: id, preferences: {}}));
  const newId = await connected(owner, target); assert.notEqual(newId, id);
  assert.equal((await db.doc(`users/${owner.uid}/safetyUsers/${newId}`).get()).data().notificationPreferences.batteryAlerts, false);
});
test('advanced preferences are server gated and independent per user', async () => {
  const owner = await actor('owner'), target = await actor('target'), second = await actor('second');
  const id = await connected(owner, target), otherId = await connected(owner, second);
  const prefs = (await db.doc(`users/${owner.uid}/safetyUsers/${id}`).get()).data().notificationPreferences;
  prefs.batteryAlerts = true;
  await assert.rejects(owner.call('updateSafetyPreferences', {relationshipId: id, preferences: prefs}));
  await db.doc(`users/${owner.uid}`).update({planTier: 'premium', subscriptionStatus: 'active'});
  await owner.call('updateSafetyPreferences', {relationshipId: id, preferences: prefs});
  assert.equal((await db.doc(`users/${owner.uid}/safetyUsers/${otherId}`).get()).data().notificationPreferences.batteryAlerts, false);
  await assert.rejects(target.call('updateSafetyPreferences', {relationshipId: id, preferences: prefs}));
});
test('direct Circle invitation reserves capacity and validates recipient and joined limit', async () => {
  const owner = await actor('owner'), target = await actor('target'), other = await actor('other');
  const id = await connected(owner, target);
  const created = await owner.call('createCircle', {name: 'Direct Circle'});
  const direct = await owner.call('createCircleInvite', {circleId: created.circleId, relationshipId: id});
  await assert.rejects(other.call('respondDirectCircleInvite', {invitationId: direct.id, accept: true}));
  await assert.rejects(owner.call('createCircleInvite', {circleId: created.circleId, relationshipId: id}));
  await target.call('respondDirectCircleInvite', {invitationId: direct.id, accept: true});
  assert.equal((await db.doc(`groups/${created.circleId}`).get()).data().memberIds.includes(target.uid), true);
  assert.equal((await db.doc(`circleInvites/${direct.id}`).get()).data().status, 'consumed');
  const another = await other.call('createCircle', {name: 'Second Circle'});
  const relationship = await connected(other, target);
  await assert.rejects(other.call('createCircleInvite', {circleId: another.circleId, relationshipId: relationship}), /joined Circle limit/);
});
test('test entitlement endpoint rejects ordinary users even on emulator', async () => {
  const owner = await actor('ordinary');
  await assert.rejects(owner.call('setTestPlan', {mode: 'premium'}));
  assert.equal((await db.doc(`users/${owner.uid}`).get()).data().planTier, 'free');
});
async function eventually(path, predicate, timeout = 12000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const snapshot = await db.doc(path).get();
    if (predicate(snapshot)) return snapshot;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  assert.fail(`Expected eventual state at ${path}`);
}
test('removal creates separate target-visible history and no-device status without leaking private fields', async () => {
  const owner = await actor('history-owner'), target = await actor('history-target');
  const id = await connected(owner, target);
  await circle('history-circle', owner, target);
  await owner.call('removeSafetyUser', {relationshipId: id});
  for (const event of [`${id}_removed`, `${id}_history-circle_removed`]) {
    const notification = await eventually(`users/${target.uid}/notifications/${event}`, doc => doc.exists);
    assert.equal(notification.data().relationshipPath, undefined);
    assert.equal(notification.data().phone, undefined);
    await eventually(`safetyEvents/${event}`, doc => doc.data()?.deliveryStatus === 'no-active-device');
  }
});
test('removed or disabled relationships suppress queued monitoring notifications', async () => {
  const owner = await actor('monitor-owner'), target = await actor('monitor-target');
  const id = await connected(owner, target);
  await owner.call('removeSafetyUser', {relationshipId: id});
  await db.doc('safetyEvents/stale-monitor').set({targetUserId: owner.uid, monitoredUserId: target.uid,
    relationshipPath: `users/${owner.uid}/safetyUsers/${id}`, category: 'emergencyAlerts', type: 'emergency_safety', title: 'SOS', body: 'Needs help', groupId: '', deliveryStatus: 'pending', createdAt: admin.firestore.FieldValue.serverTimestamp()});
  await eventually('safetyEvents/stale-monitor', doc => doc.data()?.deliveryStatus === 'cancelled');
  assert.equal((await db.doc(`users/${owner.uid}/notifications/stale-monitor`).get()).exists, false);
});
test('unconfigured email is recorded honestly and shares the same logical invitation', async () => {
  const owner = await actor('email-owner'), target = await actor('email-target');
  const {invitationId: id} = await invite(owner, target);
  await eventually(`invitationDeliveries/${id}`, doc => doc.data()?.emailStatus === 'configuration-required' && doc.data()?.pushStatus === 'no-active-device');
  await eventually(`users/${target.uid}/notifications/${id}`, doc => doc.exists);
  assert.equal((await db.collection('safetyInvites').where('ownerId', '==', owner.uid).get()).size, 1);
});
test('direct invite checks capacity again at acceptance and stale Circle rejection', async () => {
  const owner = await actor('capacity-owner'), target = await actor('capacity-target');
  const id = await connected(owner, target);
  const created = await owner.call('createCircle', {name: 'Capacity Circle'});
  const direct = await owner.call('createCircleInvite', {circleId: created.circleId, relationshipId: id});
  await db.doc(`groups/${created.circleId}`).update({memberIds: [owner.uid, 'second', 'third']});
  await assert.rejects(target.call('respondDirectCircleInvite', {invitationId: direct.id, accept: true}), /full/);
  await db.doc(`groups/${created.circleId}`).update({status: 'deleted'});
  await assert.rejects(target.call('respondDirectCircleInvite', {invitationId: direct.id, accept: true}), /active/);
});
test('allowlisted verified account can switch both test plans only when explicitly enabled', async () => {
  if (process.env.ENABLE_TEST_ENTITLEMENTS !== 'true') return;
  const email = 'nihalafaq@gmail.com';
  try { const existing = await admin.auth().getUserByEmail(email); await admin.auth().deleteUser(existing.uid); } catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
  const app = initializeApp({projectId: 'demo-alivecircle', apiKey: 'demo-key'}, 'test-plan'); apps.push(app);
  const auth = getAuth(app); connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  const {user} = await createUserWithEmailAndPassword(auth, email, 'Testing-pass-123!');
  await admin.auth().updateUser(user.uid, {emailVerified: true}); await user.getIdToken(true);
  const functions = getFunctions(app); connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  for (const mode of ['premium', 'free']) {
    await httpsCallable(functions, 'setTestPlan')({mode});
    assert.equal((await db.doc(`users/${user.uid}`).get()).data().planTier, mode);
  }
});
test('SOS monitoring reaches a connected Safety User owner outside the Circle', async () => {
  const observer = await actor('sos-observer'), sender = await actor('sos-sender'), member = await actor('sos-member');
  const id = await connected(observer, sender);
  await circle('sos-circle', sender, member);
  await db.doc('groups/sos-circle/emergencies/sos-one').set({senderId: sender.uid, senderName: 'Sender', recipientIds: [member.uid], status: 'active'});
  await eventually(`users/${observer.uid}/notifications/${id}_sos_sos-one`, doc => doc.exists);
  assert.equal((await db.doc('groups/sos-circle').get()).data().memberIds.includes(observer.uid), false);
});
test('initial Screen Time threshold uses per-user Premium preferences and emits one event', async () => {
  const owner = await actor('screen-owner'), target = await actor('screen-target');
  const id = await connected(owner, target);
  await db.doc(`users/${owner.uid}`).update({planTier: 'premium', subscriptionStatus: 'active'});
  const prefs = (await db.doc(`users/${owner.uid}/safetyUsers/${id}`).get()).data().notificationPreferences;
  await owner.call('updateSafetyPreferences', {relationshipId: id, preferences: {...prefs, screenTimeAlerts: true}});
  const source = db.doc(`users/${target.uid}/devices/device/screenTimeDaily/2026-09-13`);
  await source.set({totalTimeMs: 5 * 3600000});
  await eventually(`users/${owner.uid}/notifications/${id}_screen_2026-09-13`, doc => doc.exists);
  await source.update({totalTimeMs: 6 * 3600000});
  assert.equal((await db.collection('safetyEvents').where('monitoredUserId', '==', target.uid).get()).size, 1);
});
