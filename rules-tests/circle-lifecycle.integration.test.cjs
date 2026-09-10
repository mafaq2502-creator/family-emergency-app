const {after, before, beforeEach, test} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase/app');
const {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
} = require('firebase/auth');
const {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} = require('firebase/functions');
const {
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const projectId = 'demo-alivecircle';
let environment;
let sequence = 0;
const apps = [];

before(async () => {
  environment = await initializeTestEnvironment({projectId});
});

beforeEach(async () => {
  await environment.clearFirestore();
});

after(async () => {
  await Promise.all(apps.map(deleteApp));
  await environment.cleanup();
});

async function user(label) {
  sequence += 1;
  const app = initializeApp(
    {apiKey: 'demo-key', authDomain: `${projectId}.firebaseapp.com`, projectId},
    `${label}-${sequence}`,
  );
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  const credential = await createUserWithEmailAndPassword(
    auth,
    `${label}-${sequence}@example.test`,
    'Test-password-123!',
  );
  const functions = getFunctions(app, 'us-central1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return {uid: credential.user.uid, functions};
}

async function seedCircle(circleId, members) {
  await environment.withSecurityRulesDisabled(async context => {
    const firestore = context.firestore();
    const memberIds = members.map(member => member.uid);
    const roleMap = Object.fromEntries(members.map(member => [member.uid, member.role]));
    const owner = members.find(member => member.role === 'owner');
    await firestore.collection('groups').doc(circleId).set({
      name: 'Integration Circle',
      ownerId: owner.uid,
      memberIds,
      roles: roleMap,
      emergencyRecipientIds: memberIds,
      status: 'active',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    for (const member of members) {
      await firestore.collection('groups').doc(circleId)
        .collection('memberships').doc(member.uid).set({
          userId: member.uid,
          displayName: member.role,
          email: `${member.role}@example.test`,
          relationship: 'Family member',
          circleRole: member.role,
          status: 'active',
          joinedAt: new Date(),
          updatedAt: new Date(),
        });
      await firestore.collection('users').doc(member.uid).set({
        activeCircleId: circleId,
        circleIds: [circleId, 'another-circle'],
        updatedAt: new Date(),
      });
    }
  });
}

async function read(path) {
  let snapshot;
  await environment.withSecurityRulesDisabled(async context => {
    const parts = path.split('/');
    let reference = context.firestore().collection(parts[0]).doc(parts[1]);
    for (let index = 2; index < parts.length; index += 2) {
      reference = reference.collection(parts[index]).doc(parts[index + 1]);
    }
    snapshot = await reference.get();
  });
  return snapshot;
}

async function rejectsWithCode(promise, code) {
  await assert.rejects(promise, error => {
    assert.equal(error.code, code);
    return true;
  });
}

test('owner removes an adult and all Circle references stay consistent', async () => {
  const owner = await user('owner-remove');
  const adult = await user('adult-remove');
  await seedCircle('remove-circle', [
    {...owner, role: 'owner'},
    {...adult, role: 'adult'},
  ]);

  await httpsCallable(owner.functions, 'removeCircleMember')({
    circleId: 'remove-circle',
    memberUserId: adult.uid,
  });

  const group = (await read('groups/remove-circle')).data();
  const membership = (await read(`groups/remove-circle/memberships/${adult.uid}`)).data();
  const profile = (await read(`users/${adult.uid}`)).data();
  assert.deepEqual(group.memberIds, [owner.uid]);
  assert.equal(group.roles[adult.uid], undefined);
  assert.deepEqual(group.emergencyRecipientIds, [owner.uid]);
  assert.equal(membership.status, 'removed');
  assert.equal(profile.activeCircleId, undefined);
  assert.deepEqual(profile.circleIds, ['another-circle']);
});

test('parent can remove a child but cannot remove another parent', async () => {
  const owner = await user('owner-parent-policy');
  const parent = await user('parent-actor');
  const otherParent = await user('parent-target');
  const child = await user('child-target');
  await seedCircle('parent-policy-circle', [
    {...owner, role: 'owner'},
    {...parent, role: 'parent'},
    {...otherParent, role: 'parent'},
    {...child, role: 'child'},
  ]);

  await httpsCallable(parent.functions, 'removeCircleMember')({
    circleId: 'parent-policy-circle', memberUserId: child.uid,
  });
  await rejectsWithCode(
    httpsCallable(parent.functions, 'removeCircleMember')({
      circleId: 'parent-policy-circle', memberUserId: otherParent.uid,
    }),
    'functions/permission-denied',
  );
});

test('adult cannot remove a member and owner cannot leave', async () => {
  const owner = await user('owner-leave');
  const adult = await user('adult-denied');
  await seedCircle('denied-circle', [
    {...owner, role: 'owner'},
    {...adult, role: 'adult'},
  ]);

  await rejectsWithCode(
    httpsCallable(adult.functions, 'removeCircleMember')({
      circleId: 'denied-circle', memberUserId: owner.uid,
    }),
    'functions/permission-denied',
  );
  await rejectsWithCode(
    httpsCallable(owner.functions, 'leaveCircle')({circleId: 'denied-circle'}),
    'functions/failed-precondition',
  );
});

test('adult leaves and its membership and profile references are cleaned', async () => {
  const owner = await user('owner-adult-leave');
  const adult = await user('adult-leave');
  await seedCircle('leave-circle', [
    {...owner, role: 'owner'},
    {...adult, role: 'adult'},
  ]);

  await httpsCallable(adult.functions, 'leaveCircle')({circleId: 'leave-circle'});

  const group = (await read('groups/leave-circle')).data();
  const membership = (await read(`groups/leave-circle/memberships/${adult.uid}`)).data();
  const profile = (await read(`users/${adult.uid}`)).data();
  assert.deepEqual(group.memberIds, [owner.uid]);
  assert.equal(membership.status, 'left');
  assert.equal(profile.activeCircleId, undefined);
  assert.deepEqual(profile.circleIds, ['another-circle']);
});

test('only owner deletes a Circle and every membership/profile is cleaned', async () => {
  const owner = await user('owner-delete');
  const adult = await user('adult-delete');
  await seedCircle('delete-circle', [
    {...owner, role: 'owner'},
    {...adult, role: 'adult'},
  ]);

  await rejectsWithCode(
    httpsCallable(adult.functions, 'deleteCircle')({circleId: 'delete-circle'}),
    'functions/permission-denied',
  );
  await httpsCallable(owner.functions, 'deleteCircle')({circleId: 'delete-circle'});

  const group = (await read('groups/delete-circle')).data();
  assert.equal(group.status, 'deleted');
  assert.deepEqual(group.memberIds, []);
  assert.deepEqual(group.roles, {});
  for (const member of [owner, adult]) {
    const membership = (await read(`groups/delete-circle/memberships/${member.uid}`)).data();
    const profile = (await read(`users/${member.uid}`)).data();
    assert.equal(membership.status, 'removed');
    assert.equal(profile.activeCircleId, undefined);
    assert.deepEqual(profile.circleIds, ['another-circle']);
  }
});

test('concurrent removal attempts produce one success and consistent state', async () => {
  const owner = await user('owner-concurrent');
  const adult = await user('adult-concurrent');
  await seedCircle('concurrent-circle', [
    {...owner, role: 'owner'},
    {...adult, role: 'adult'},
  ]);
  const remove = httpsCallable(owner.functions, 'removeCircleMember');

  const outcomes = await Promise.allSettled([
    remove({circleId: 'concurrent-circle', memberUserId: adult.uid}),
    remove({circleId: 'concurrent-circle', memberUserId: adult.uid}),
  ]);
  assert.equal(outcomes.filter(result => result.status === 'fulfilled').length, 1);
  assert.equal(outcomes.filter(result => result.status === 'rejected').length, 1);

  const group = (await read('groups/concurrent-circle')).data();
  const membership = (await read(`groups/concurrent-circle/memberships/${adult.uid}`)).data();
  assert.deepEqual(group.memberIds, [owner.uid]);
  assert.equal(membership.status, 'removed');
});
