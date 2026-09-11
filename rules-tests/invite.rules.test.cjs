const fs = require('node:fs');
const path = require('node:path');
const {after, before, beforeEach, test} = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  arrayUnion,
  collection,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} = require('firebase/firestore');

const inviteId = 'ABCDEFGHJKLMNPQRSTUV2345';
let environment;

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
      memberIds: ['owner-1', 'parent-1', 'adult-1'],
      roles: {
        'owner-1': 'owner',
        'parent-1': 'parent',
        'adult-1': 'adult',
      },
      emergencyRecipientIds: ['owner-1'],
      status: 'active',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    for (const [id, role] of [
      ['owner-1', 'owner'],
      ['parent-1', 'parent'],
      ['adult-1', 'adult'],
    ]) {
      await setDoc(doc(db, `groups/circle-1/memberships/${id}`), {
        userId: id,
        displayName: id,
        relationship: 'Family member',
        circleRole: role,
        status: 'active',
        joinedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }
    await setDoc(doc(db, 'users/requester-1'), {
      name: 'Requester',
      email: 'requester@example.test',
      circleIds: [],
      profileCompleted: true,
      onboardingCompleted: false,
      updatedAt: serverTimestamp(),
    });
  });
});

after(async () => environment.cleanup());

function inviteData(overrides = {}) {
  return {
    circleId: 'circle-1',
    circleName: 'My Family',
    createdBy: 'owner-1',
    createdAt: serverTimestamp(),
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    status: 'active',
    inviteType: 'multiUse',
    maxUses: 20,
    useCount: 0,
    requiresApproval: true,
    circleRole: 'adult',
    ...overrides,
  };
}

async function seedInvite(overrides = {}) {
  await environment.withSecurityRulesDisabled(async context => {
    await setDoc(
      doc(context.firestore(), `circleInvites/${inviteId}`),
      inviteData(overrides),
    );
  });
}

function requestData(overrides = {}) {
  return {
    circleId: 'circle-1',
    userUid: 'requester-1',
    inviteId,
    displayName: 'Requester',
    email: 'requester@example.test',
    relationship: 'Relative',
    circleRole: 'adult',
    status: 'pending',
    requestedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

async function seedRequest() {
  await seedInvite();
  const requester = environment
      .authenticatedContext('requester-1')
      .firestore();
  await assertSucceeds(
    setDoc(
      doc(requester, 'groups/circle-1/joinRequests/requester-1'),
      requestData(),
    ),
  );
}

function approvalBatch(db, reviewerId = 'owner-1', inviteStatus = 'active') {
  const batch = writeBatch(db);
  batch.update(doc(db, 'groups/circle-1'), {
    memberIds: arrayUnion('requester-1'),
    roles: {
      'owner-1': 'owner',
      'parent-1': 'parent',
      'adult-1': 'adult',
      'requester-1': 'adult',
    },
    lastApprovedUserId: 'requester-1',
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(db, 'groups/circle-1/memberships/requester-1'), {
    userId: 'requester-1',
    displayName: 'Requester',
    email: 'requester@example.test',
    relationship: 'Relative',
    circleRole: 'adult',
    status: 'active',
    joinedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(db, 'groups/circle-1/joinRequests/requester-1'), {
    status: 'approved',
    reviewedBy: reviewerId,
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(db, `circleInvites/${inviteId}`), {
    useCount: 1,
    status: inviteStatus,
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(db, 'users/requester-1'), {
    onboardingCompleted: true,
    activeCircleId: 'circle-1',
    circleIds: arrayUnion('circle-1'),
    pendingJoinCircleId: deleteField(),
    pendingJoinInviteId: deleteField(),
    updatedAt: serverTimestamp(),
  });
  return batch;
}

test('only managers create valid secure invites and exact-token reads work', async () => {
  const owner = environment.authenticatedContext('owner-1').firestore();
  const adult = environment.authenticatedContext('adult-1').firestore();
  const outsider = environment.authenticatedContext('outsider-1').firestore();
  const anonymous = environment.unauthenticatedContext().firestore();

  await assertSucceeds(
    setDoc(doc(owner, `circleInvites/${inviteId}`), inviteData()),
  );
  await assertFails(
    setDoc(
      doc(adult, 'circleInvites/BCDEFGHJKLMNPQRSTUV23456'),
      inviteData({createdBy: 'adult-1'}),
    ),
  );
  await assertSucceeds(getDoc(doc(outsider, `circleInvites/${inviteId}`)));
  await assertFails(getDoc(doc(anonymous, `circleInvites/${inviteId}`)));
  await assertFails(
    getDocs(
      query(
        collection(outsider, 'circleInvites'),
        where('circleId', '==', 'circle-1'),
      ),
    ),
  );
});

test('valid invite creates one pending request but cannot be resubmitted', async () => {
  await seedInvite();
  const requester = environment
      .authenticatedContext('requester-1')
      .firestore();
  const request = doc(
    requester,
    'groups/circle-1/joinRequests/requester-1',
  );
  await assertSucceeds(setDoc(request, requestData()));
  await assertFails(setDoc(request, requestData()));
});

test('expired, revoked, and exhausted invites cannot create join requests', async () => {
  const requester = environment
      .authenticatedContext('requester-1')
      .firestore();
  const request = doc(
    requester,
    'groups/circle-1/joinRequests/requester-1',
  );
  await seedInvite({expiresAt: new Date(Date.now() - 1000)});
  await assertFails(setDoc(request, requestData()));
  await seedInvite({status: 'revoked'});
  await assertFails(setDoc(request, requestData()));
  await seedInvite({status: 'exhausted', useCount: 20});
  await assertFails(setDoc(request, requestData()));
});

test('requester cannot approve itself or directly create membership', async () => {
  await seedRequest();
  const requester = environment
      .authenticatedContext('requester-1')
      .firestore();
  await assertFails(
    updateDoc(
      doc(requester, 'groups/circle-1/joinRequests/requester-1'),
      {
        status: 'approved',
        reviewedBy: 'requester-1',
        reviewedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    ),
  );
  await assertFails(
    setDoc(doc(requester, 'groups/circle-1/memberships/requester-1'), {
      userId: 'requester-1',
      displayName: 'Requester',
      relationship: 'Relative',
      circleRole: 'owner',
      status: 'active',
      joinedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('owner approval atomically creates least-privilege membership', async () => {
  await seedRequest();
  const owner = environment.authenticatedContext('owner-1').firestore();
  await assertSucceeds(approvalBatch(owner).commit());
});

test('final invite use atomically exhausts the invite', async () => {
  await seedInvite({maxUses: 1});
  const requester = environment
      .authenticatedContext('requester-1')
      .firestore();
  await assertSucceeds(
    setDoc(
      doc(requester, 'groups/circle-1/joinRequests/requester-1'),
      requestData(),
    ),
  );
  const owner = environment.authenticatedContext('owner-1').firestore();
  await assertSucceeds(approvalBatch(owner, 'owner-1', 'exhausted').commit());
});

test('two managers cannot approve the same request twice', async () => {
  await seedRequest();
  const owner = environment.authenticatedContext('owner-1').firestore();
  const parent = environment.authenticatedContext('parent-1').firestore();
  const results = await Promise.allSettled([
    approvalBatch(owner, 'owner-1').commit(),
    approvalBatch(parent, 'parent-1').commit(),
  ]);
  const fulfilled = results.filter(result => result.status === 'fulfilled');
  const rejected = results.filter(result => result.status === 'rejected');
  if (fulfilled.length !== 1 || rejected.length !== 1) {
    throw new Error(`Expected one approval, got ${fulfilled.length}`);
  }
});

test('approve and reject race resolves to exactly one terminal state', async () => {
  await seedRequest();
  const owner = environment.authenticatedContext('owner-1').firestore();
  const parent = environment.authenticatedContext('parent-1').firestore();
  const reject = updateDoc(
    doc(parent, 'groups/circle-1/joinRequests/requester-1'),
    {
      status: 'rejected',
      reviewedBy: 'parent-1',
      reviewedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    },
  );
  const results = await Promise.allSettled([
    approvalBatch(owner, 'owner-1').commit(),
    reject,
  ]);
  const fulfilled = results.filter(result => result.status === 'fulfilled');
  const rejected = results.filter(result => result.status === 'rejected');
  if (fulfilled.length !== 1 || rejected.length !== 1) {
    throw new Error(`Expected one terminal write, got ${fulfilled.length}`);
  }
});

test('normal member cannot approve or reject a request', async () => {
  await seedRequest();
  const adult = environment.authenticatedContext('adult-1').firestore();
  await assertFails(
    updateDoc(doc(adult, 'groups/circle-1/joinRequests/requester-1'), {
      status: 'rejected',
      reviewedBy: 'adult-1',
      reviewedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('manager can reject a pending request without creating membership', async () => {
  await seedRequest();
  const owner = environment.authenticatedContext('owner-1').firestore();
  await assertSucceeds(
    updateDoc(doc(owner, 'groups/circle-1/joinRequests/requester-1'), {
      status: 'rejected',
      reviewedBy: 'owner-1',
      reviewedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  const membership = await getDoc(
    doc(owner, 'groups/circle-1/memberships/requester-1'),
  );
  if (membership.exists()) {
    throw new Error('Rejected requester received a membership');
  }
});

test('only manager can revoke an active invite', async () => {
  await seedInvite();
  const owner = environment.authenticatedContext('owner-1').firestore();
  const adult = environment.authenticatedContext('adult-1').firestore();
  await assertFails(
    updateDoc(doc(adult, `circleInvites/${inviteId}`), {
      status: 'revoked',
      revokedBy: 'adult-1',
      revokedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(doc(owner, `circleInvites/${inviteId}`), {
      status: 'revoked',
      revokedBy: 'owner-1',
      revokedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});
