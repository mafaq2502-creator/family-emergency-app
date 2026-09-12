const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { collection, query, where, limit, getDocs, doc, getDoc, serverTimestamp, setDoc, updateDoc, writeBatch, deleteField, deleteDoc } = require('firebase/firestore');

let testEnvironment;

for (const activeCircleId of ['circle-1', 'another-circle']) {
  test(`owner deletion tolerates legacy profile fields, active=${activeCircleId}`, async () => {
    await testEnvironment.withSecurityRulesDisabled(async context => {
      await updateDoc(doc(context.firestore(), 'users/owner-1'), {
        role: 'Father', relationship: 'Legacy relationship',
        circleIds: ['circle-1', 'another-circle'], activeCircleId,
      });
    });
    const owner = testEnvironment.authenticatedContext('owner-1').firestore();
    const cleanup = {
      circleIds: ['another-circle'], updatedAt: serverTimestamp(),
      ...(activeCircleId === 'circle-1' ? {activeCircleId: deleteField()} : {}),
    };
    await assertFails(updateDoc(doc(owner, 'users/owner-1'), cleanup));
    const makeBatch = (extra = {}) => {
      const batch = writeBatch(owner);
      batch.update(doc(owner, 'groups/circle-1'), {
        status: 'deleted', deletedBy: 'owner-1', deletedAt: serverTimestamp(),
        memberIds: [], roles: {}, emergencyRecipientIds: [], updatedAt: serverTimestamp(),
      });
      batch.update(doc(owner, 'users/owner-1'), {...cleanup, ...extra});
      return batch;
    };
    await assertFails(makeBatch({name: 'Unauthorized profile edit'}).commit());
    await assertFails(makeBatch({circleIds: []}).commit());
    await assertFails(makeBatch().commit());
  });
}

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
    for (const [id, name, relationship] of [
      ['owner-1', 'Owner', 'Self'],
      ['adult-1', 'Adult', 'Other'],
    ]) {
      await setDoc(doc(db, `users/${id}`), {
        uid: id, name, email: `${id}@example.test`, relationship,
        phone: '+923001234567', phoneCountryIso: 'PK', phoneCountryCode: '+92',
        profileCompleted: true, onboardingCompleted: true,
        planTier: 'premium', subscriptionStatus: 'active',
        circleIds: ['circle-1'], activeCircleId: 'circle-1',
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      });
    }
  });
});

after(async () => testEnvironment.cleanup());

test('login can query active Circles and safely return an empty result for a new account', async () => {
  for (const uid of ['owner-1', 'new-user']) {
    const db = testEnvironment.authenticatedContext(uid).firestore();
    await assertSucceeds(getDocs(query(collection(db, 'groups'),
      where('memberIds', 'array-contains', uid), where('status', '==', 'active'), limit(1))));
  }
});

test('Circle listing rejects outsiders, unfiltered queries and deleted Circles', async () => {
  const db = testEnvironment.authenticatedContext('outsider').firestore();
  await assertFails(getDocs(collection(db, 'groups')));
  await assertFails(getDocs(query(collection(db, 'groups'),
    where('memberIds', 'array-contains', 'owner-1'), where('status', '==', 'active'))));
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'groups/circle-1'), {status: 'deleted'});
  });
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  const result = await assertSucceeds(getDocs(query(collection(owner, 'groups'),
    where('memberIds', 'array-contains', 'owner-1'), where('status', '==', 'active'))));
  require('node:assert/strict').equal(result.size, 0);
});

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

test('profile ownership blocks IDOR and unexpected identity fields', async () => {
  const owner = testEnvironment.authenticatedContext('owner-1', {email: 'owner-1@example.test'}).firestore();
  const adult = testEnvironment.authenticatedContext('adult-1', {email: 'adult-1@example.test'}).firestore();
  await assertSucceeds(getDoc(doc(owner, 'users/owner-1')));
  await assertFails(getDoc(doc(owner, 'users/adult-1')));
  await assertFails(updateDoc(doc(owner, 'users/adult-1'), {name: 'Taken over'}));
  await assertFails(updateDoc(doc(owner, 'users/owner-1'), {ownerId: 'adult-1'}));
  await assertFails(updateDoc(doc(owner, 'users/owner-1'), {email: 'adult-1@example.test'}));
  await assertSucceeds(updateDoc(doc(adult, 'users/adult-1'), {
    name: 'Adult Updated', relationship: 'Brother', updatedAt: serverTimestamp(),
  }));
});

test('profile and own membership identity update atomically', async () => {
  const adult = testEnvironment.authenticatedContext('adult-1', {email: 'adult-1@example.test'}).firestore();
  const batch = writeBatch(adult);
  batch.update(doc(adult, 'users/adult-1'), {
    name: 'Adult Updated', relationship: 'Brother', updatedAt: serverTimestamp(),
  });
  batch.update(doc(adult, 'groups/circle-1/memberships/adult-1'), {
    displayName: 'Adult Updated', relationship: 'Brother', updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(adult, 'groups/circle-1/memberships/adult-1'), {
    displayName: 'Spoofed', relationship: 'Brother', updatedAt: serverTimestamp(),
  }));
  const group = await getDoc(doc(adult, 'groups/circle-1'));
  require('node:assert/strict').equal(group.data().roles['adult-1'], 'adult');
});

test('profile creation is canonical, owner-scoped and server validated', async () => {
  const user = testEnvironment.authenticatedContext('new-user', {email: 'new@example.test'}).firestore();
  const outsider = testEnvironment.authenticatedContext('outsider', {email: 'outside@example.test'}).firestore();
  const valid = {
    uid: 'new-user', name: 'New User', email: 'new@example.test',
    phone: '+923001234567', phoneCountryIso: 'PK', phoneCountryCode: '+92',
    relationship: 'Self', profileCompleted: true, onboardingCompleted: false,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(user, 'users/new-user'), valid));
  await assertFails(setDoc(doc(outsider, 'users/another-user'), {...valid, uid: 'another-user'}));
  await assertFails(updateDoc(doc(user, 'users/new-user'), {uid: 'another-user'}));
  await assertFails(updateDoc(doc(user, 'users/new-user'), {name: 'x'.repeat(81)}));
  await assertFails(updateDoc(doc(user, 'users/new-user'), {relationship: 'Administrator'}));
  await assertFails(updateDoc(doc(user, 'users/new-user'), {address: {city: 42}}));
  await assertFails(updateDoc(doc(user, 'users/new-user'), {address: {line1: 'x'.repeat(201)}}));
  await assertFails(updateDoc(doc(user, 'users/new-user'), {address: {countryIso: 'Pakistan'}}));
  await assertSucceeds(updateDoc(doc(user, 'users/new-user'), {
    address: {city: 'Lahore', countryIso: 'PK'}, updatedAt: serverTimestamp(),
  }));
});

test('deletion dependency query returns only the caller membership scope', async () => {
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  const outsider = testEnvironment.authenticatedContext('outsider').firestore();
  const own = query(collection(owner, 'groups'), where('memberIds', 'array-contains', 'owner-1'),
    where('status', '==', 'active'), limit(20));
  const other = query(collection(outsider, 'groups'), where('memberIds', 'array-contains', 'owner-1'),
    where('status', '==', 'active'), limit(20));
  await assertSucceeds(getDocs(own));
  await assertFails(getDocs(other));
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

test('Circle creation is restricted to the trusted entitlement function', async () => {
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
  await assertFails(batch.commit());
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

test('Circle deletion is restricted to the trusted lifecycle function', async () => {
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  await assertFails(updateDoc(doc(adult, 'groups/circle-1'), {
    status: 'deleted', deletedBy: 'adult-1', deletedAt: serverTimestamp(),
    memberIds: [], roles: {}, emergencyRecipientIds: [], updatedAt: serverTimestamp(),
  }));
  const owner = testEnvironment.authenticatedContext('owner-1', {email: 'owner-1@example.test'}).firestore();
  await assertFails(updateDoc(doc(owner, 'groups/circle-1'), {
    status: 'deleted', deletedBy: 'owner-1', deletedAt: serverTimestamp(),
    memberIds: [], roles: {}, emergencyRecipientIds: [], updatedAt: serverTimestamp(),
  }));
});

test('Circle notifications cannot be deleted without the matching owner tombstone', async () => {
  await testEnvironment.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/owner-1/notifications/circle-notice'), {
      groupId: 'circle-1', title: 'Circle alert',
    });
  });
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  await assertFails(deleteDoc(doc(owner, 'users/owner-1/notifications/circle-notice')));
  await assertFails(deleteDoc(doc(adult, 'users/owner-1/notifications/circle-notice')));
});

test('deletion cleanup cannot unpair records without a matching owner tombstone', async () => {
  await testEnvironment.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'groups/circle-1/devices/test-device'), {ownerUserId: 'adult-1', pairingStatus: 'paired'});
  });
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  await assertFails(updateDoc(doc(owner, 'groups/circle-1/devices/test-device'), {
    pairingStatus: 'unpaired', removedBy: 'owner-1', removedAt: serverTimestamp(), updatedAt: serverTimestamp(), name: 'tampered',
  }));
});
