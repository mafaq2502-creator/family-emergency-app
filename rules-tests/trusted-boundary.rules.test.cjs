const fs = require('node:fs');
const path = require('node:path');
const {after, before, beforeEach, test} = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

let environment;
const inviteId = 'ABCDEFGHJKLMNPQRSTUV2345';

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-alivecircle',
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'groups/circle-1'), {
      name: 'My Family',
      ownerId: 'owner-1',
      ownerPlanTier: 'free',
      memberIds: ['owner-1', 'member-1'],
      roles: {'owner-1': 'owner', 'member-1': 'adult'},
      emergencyRecipientIds: ['member-1'],
      status: 'active',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    for (const [uid, circleIds] of [
      ['owner-1', ['circle-1']],
      ['member-1', ['circle-1']],
      ['outsider-1', []],
    ]) {
      await setDoc(doc(db, `users/${uid}`), {
        uid,
        name: uid,
        email: `${uid}@example.test`,
        planTier: 'free',
        subscriptionStatus: 'inactive',
        circleIds,
        ownedCircleIds: uid === 'owner-1' ? ['circle-1'] : [],
        joinedCircleIds: uid === 'member-1' ? ['circle-1'] : [],
        profileCompleted: true,
        onboardingCompleted: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }
    await setDoc(doc(db, `circleInvites/${inviteId}`), {
      circleId: 'circle-1',
      circleName: 'My Family',
      createdBy: 'owner-1',
      createdAt: serverTimestamp(),
      expiresAt: new Date(Date.now() + 86400000),
      status: 'active',
      maxUses: 1,
      useCount: 0,
      requiresApproval: true,
      circleRole: 'adult',
    });
  });
});

after(async () => environment.cleanup());

test('entitlement and membership mutations are callable-only', async () => {
  const owner = environment.authenticatedContext('owner-1').firestore();
  const outsider = environment.authenticatedContext('outsider-1').firestore();

  await assertFails(setDoc(doc(owner, 'groups/circle-2'), {
    name: 'Second Circle', ownerId: 'owner-1', memberIds: ['owner-1'],
    roles: {'owner-1': 'owner'}, emergencyRecipientIds: ['owner-1'],
    status: 'active', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(owner, 'circleInvites/SECONDINVITECODE23456789AB'), {
    circleId: 'circle-1', status: 'active', maxUses: 1,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(outsider, 'groups/circle-1/joinRequests/outsider-1'), {
    circleId: 'circle-1', userUid: 'outsider-1', inviteId,
    status: 'pending', requestedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(owner, `circleInvites/${inviteId}`), {
    status: 'consumed', useCount: 1, updatedAt: serverTimestamp(),
  }));
});

test('signed-in users can resolve an exact invitation token', async () => {
  const outsider = environment.authenticatedContext('outsider-1').firestore();
  await assertSucceeds(getDoc(doc(outsider, `circleInvites/${inviteId}`)));
});

test('SOS recipients must be selected live members other than the sender', async () => {
  const owner = environment.authenticatedContext('owner-1').firestore();
  const base = {
    senderId: 'owner-1',
    senderName: 'Owner',
    status: 'active',
    createdAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(owner, 'groups/circle-1/emergencies/valid'), {
    ...base, recipientIds: ['member-1'],
  }));
  await assertFails(setDoc(doc(owner, 'groups/circle-1/emergencies/self'), {
    ...base, recipientIds: ['owner-1'],
  }));
  await assertFails(setDoc(doc(owner, 'groups/circle-1/emergencies/outsider'), {
    ...base, recipientIds: ['outsider-1'],
  }));
});
