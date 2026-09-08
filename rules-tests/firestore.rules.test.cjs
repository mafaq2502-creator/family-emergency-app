const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, getDoc, serverTimestamp, setDoc, updateDoc, writeBatch } = require('firebase/firestore');

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: 'demo-alivecircle',
    firestore: { rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'groups/circle-1'), {
      name: 'My Family', ownerId: 'owner-1', memberIds: ['owner-1', 'adult-1'],
      roles: { 'owner-1': 'owner', 'adult-1': 'adult' }, emergencyRecipientIds: ['owner-1'],
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    await setDoc(doc(db, 'groups/circle-1/memberships/owner-1'), {
      userId: 'owner-1', displayName: 'Owner', relationship: 'Self', circleRole: 'owner',
      status: 'active', joinedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
  });
});

after(async () => testEnvironment.cleanup());

test('Circle documents are visible only to cached members', async () => {
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  const outsider = testEnvironment.authenticatedContext('outsider-1').firestore();
  const anonymous = testEnvironment.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(owner, 'groups/circle-1')));
  await assertSucceeds(getDoc(doc(adult, 'groups/circle-1')));
  await assertFails(getDoc(doc(outsider, 'groups/circle-1')));
  await assertFails(getDoc(doc(anonymous, 'groups/circle-1')));
});

test('only a Circle manager can rename a Circle', async () => {
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  await assertSucceeds(updateDoc(doc(owner, 'groups/circle-1'), { name: 'Home Circle', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(adult, 'groups/circle-1'), { name: 'Unauthorized', updatedAt: serverTimestamp() }));
});

test('new Circle and owner membership can be created atomically', async () => {
  const owner = testEnvironment.authenticatedContext('new-owner').firestore();
  const batch = writeBatch(owner);
  batch.set(doc(owner, 'groups/circle-2'), {
    name: 'Second Family', ownerId: 'new-owner', memberIds: ['new-owner'],
    roles: { 'new-owner': 'owner' }, emergencyRecipientIds: ['new-owner'],
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  batch.set(doc(owner, 'groups/circle-2/memberships/new-owner'), {
    userId: 'new-owner', displayName: 'New Owner', relationship: 'Self', circleRole: 'owner',
    status: 'active', joinedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
});

test('members can write only their own progress record', async () => {
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  await assertSucceeds(setDoc(doc(adult, 'groups/circle-1/progressDaily/adult-1_2026-09-07'), {
    userId: 'adult-1', localDate: '2026-09-07', screenTimeMinutes: 90, updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(adult, 'groups/circle-1/progressDaily/owner-1_2026-09-07'), {
    userId: 'owner-1', localDate: '2026-09-07', screenTimeMinutes: 90, updatedAt: serverTimestamp(),
  }));
});

test('clients cannot create notification documents', async () => {
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  await assertFails(setDoc(doc(owner, 'users/owner-1/notifications/fake'), { title: 'Fake alert', isRead: false }));
});
