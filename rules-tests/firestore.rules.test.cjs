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
      name: 'My Family', ownerId: 'owner-1', memberIds: ['owner-1', 'parent-1', 'adult-1'],
      roles: { 'owner-1': 'owner', 'parent-1': 'parent', 'adult-1': 'adult' }, emergencyRecipientIds: ['owner-1'],
      status: 'active', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    await setDoc(doc(db, 'groups/circle-1/memberships/owner-1'), {
      userId: 'owner-1', displayName: 'Owner', relationship: 'Self', circleRole: 'owner',
      status: 'active', joinedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    await setDoc(doc(db, 'groups/circle-1/memberships/adult-1'), {
      userId: 'adult-1', displayName: 'Adult', relationship: 'Sibling', circleRole: 'adult',
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

test('manager cannot configure an emergency recipient outside the Circle', async () => {
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  await assertFails(updateDoc(doc(owner, 'groups/circle-1'), {
    emergencyRecipientIds: ['owner-1', 'outsider-1'], updatedAt: serverTimestamp(),
  }));
});

test('new Circle and owner membership can be created atomically', async () => {
  const owner = testEnvironment.authenticatedContext('new-owner').firestore();
  const batch = writeBatch(owner);
  batch.set(doc(owner, 'groups/circle-2'), {
    name: 'Second Family', ownerId: 'new-owner', memberIds: ['new-owner'],
    roles: { 'new-owner': 'owner' }, emergencyRecipientIds: ['new-owner'],
    status: 'active', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
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

test('client lifecycle writes cannot desynchronize embedded membership state', async () => {
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  const parent = testEnvironment.authenticatedContext('parent-1').firestore();
  await assertFails(updateDoc(doc(owner, 'groups/circle-1'), {
    memberIds: ['owner-1'], roles: { 'owner-1': 'owner' }, updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(parent, 'groups/circle-1/memberships/adult-1'), {
    status: 'removed', updatedAt: serverTimestamp(),
  }));
});

test('malformed roles never grant manager privileges', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'groups/circle-1'), {
      memberIds: ['owner-1', 'outsider-1'],
      roles: { 'owner-1': 'owner', 'outsider-1': 'super_owner' },
    });
  });
  const outsider = testEnvironment.authenticatedContext('outsider-1').firestore();
  await assertFails(updateDoc(doc(outsider, 'groups/circle-1'), {
    name: 'Escalated', updatedAt: serverTimestamp(),
  }));
});

test('deleted Circle is not readable when a stale member id remains', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'groups/circle-1'), {status: 'deleted'});
  });
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  await assertFails(getDoc(doc(owner, 'groups/circle-1')));
});
