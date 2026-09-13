const fs = require('node:fs');
const path = require('node:path');
const {before, beforeEach, after, test} = require('node:test');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, getDocs, collection, query, where} = require('firebase/firestore');
let env;
before(async () => { env = await initializeTestEnvironment({projectId: 'demo-alivecircle', firestore: {rules: fs.readFileSync(path.join(__dirname, '../firestore.rules'), 'utf8')}}); });
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/owner/safetyUsers/invite'), {ownerId: 'owner', targetUserId: 'target', phone: '+923001234567', email: 'target@example.test', notificationPreferences: {emergencyAlerts: true}, status: 'connected'});
    await setDoc(doc(db, 'safetyInvites/invite'), {ownerId: 'owner', targetUserId: 'target', email: 'target@example.test', status: 'pending'});
    await setDoc(doc(db, 'groups/circle'), {ownerId: 'owner', memberIds: ['owner', 'target', 'ordinary'], roles: {owner: 'owner', target: 'adult', ordinary: 'adult'}, status: 'active'});
    await setDoc(doc(db, 'groups/circle/memberships/target'), {userId: 'target', email: 'target@example.test', relationship: 'Brother', status: 'active'});
    await setDoc(doc(db, 'groups/circle/publicMembers/target'), {userId: 'target', displayName: 'Target', status: 'active'});
    await setDoc(doc(db, 'circleInvites/direct'), {circleId: 'circle', createdBy: 'owner', targetUserId: 'target', email: 'target@example.test', status: 'active'});
  });
});
const user = (uid, claims = {}) => env.authenticatedContext(uid, claims).firestore();
test('Added User details are owner-private and no client can mutate them', async () => {
  await assertSucceeds(getDoc(doc(user('owner'), 'users/owner/safetyUsers/invite')));
  for (const uid of ['target', 'ordinary', 'outsider']) await assertFails(getDoc(doc(user(uid), 'users/owner/safetyUsers/invite')));
  await assertFails(setDoc(doc(user('owner'), 'users/owner/safetyUsers/new'), {status: 'connected'}));
});
test('only verified intended email can query incoming requests', async () => {
  const incoming = db => query(collection(db, 'safetyInvites'), where('email', '==', 'target@example.test'));
  await assertSucceeds(getDocs(incoming(user('target', {email: 'target@example.test', email_verified: true}))));
  await assertFails(getDocs(incoming(user('outsider', {email: 'other@example.test', email_verified: true}))));
  await assertFails(getDocs(incoming(user('target', {email: 'target@example.test', email_verified: false}))));
  await assertFails(setDoc(doc(user('target'), 'safetyInvites/invite'), {status: 'accepted'}));
});
test('ordinary Circle members read public names but cannot retrieve private identities', async () => {
  await assertSucceeds(getDocs(collection(user('ordinary'), 'groups/circle/publicMembers')));
  await assertFails(getDoc(doc(user('ordinary'), 'groups/circle/memberships/target')));
  await assertFails(getDoc(doc(user('outsider'), 'groups/circle/publicMembers/target')));
});
test('direct invitations cannot be read by unrelated known-ID callers', async () => {
  await assertFails(getDoc(doc(user('ordinary'), 'circleInvites/direct')));
  await assertSucceeds(getDocs(query(collection(user('target', {email: 'target@example.test', email_verified: true}), 'circleInvites'), where('email', '==', 'target@example.test'))));
});
test('delivery outboxes and test entitlements are not client writable', async () => {
  for (const target of ['safetyEvents/fake', 'invitationDeliveries/fake']) await assertFails(setDoc(doc(user('owner'), target), {targetUserId: 'target'}));
});
