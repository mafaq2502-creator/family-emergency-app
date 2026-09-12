const fs = require('node:fs');
const path = require('node:path');
const {after, before, beforeEach, test} = require('node:test');
const assert = require('node:assert/strict');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  deleteField,
} = require('firebase/firestore');

const installationId = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const associationId = `adult-1_${installationId}`;
const pairingId = 'ABCDEFGHJKLMNPQRSTUVWX23';
let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: 'demo-alivecircle',
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const uid of ['owner-1', 'adult-1', 'outsider-1']) {
      await setDoc(doc(db, `users/${uid}`), {
        uid,
        name: uid,
        email: `${uid}@example.test`,
        relationship: uid === 'owner-1' ? 'Self' : 'Other',
        profileCompleted: true,
        onboardingCompleted: true,
        circleIds: uid === 'outsider-1' ? [] : ['circle-1'],
        activeCircleId: uid === 'outsider-1' ? null : 'circle-1',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }
    await setDoc(doc(db, 'groups/circle-1'), {
      name: 'Family',
      ownerId: 'owner-1',
      memberIds: ['owner-1', 'adult-1'],
      roles: {'owner-1': 'owner', 'adult-1': 'adult'},
      emergencyRecipientIds: ['owner-1'],
      status: 'active',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    for (const [uid, role] of [['owner-1', 'owner'], ['adult-1', 'adult']]) {
      await setDoc(doc(db, `groups/circle-1/memberships/${uid}`), {
        userId: uid,
        displayName: uid,
        relationship: uid === 'owner-1' ? 'Self' : 'Other',
        circleRole: role,
        status: 'active',
        joinedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }
  });
});

after(async () => testEnvironment.cleanup());

function installationData(uid = 'adult-1') {
  return {
    installationId,
    ownerUserId: uid,
    name: 'Android device',
    platform: 'android',
    appVersion: '1.0.0',
    status: 'active',
    pairingStatus: 'registered',
    registeredAt: serverTimestamp(),
    lastSeenAt: serverTimestamp(),
    lastHeartbeatAt: serverTimestamp(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

async function seedOldInstallation(uid = 'adult-1', status = 'active') {
  await testEnvironment.withSecurityRulesDisabled(async context => {
    const old = Timestamp.fromMillis(Date.now() - 5 * 60 * 1000);
    await setDoc(doc(context.firestore(), `users/${uid}/devices/${installationId}`), {
      installationId,
      ownerUserId: uid,
      name: 'Android device',
      platform: 'android',
      appVersion: '1.0.0',
      status,
      pairingStatus: status === 'revoked' ? 'revoked' : 'registered',
      registeredAt: old,
      lastSeenAt: old,
      lastHeartbeatAt: old,
      createdAt: old,
      updatedAt: old,
    });
  });
}

async function seedPairingRequest(ownerUserId = 'adult-1') {
  await testEnvironment.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), `devicePairingRequests/${pairingId}`), {
      ownerUserId,
      installationId,
      deviceName: 'Android device',
      platform: 'android',
      appVersion: '1.0.0',
      status: 'active',
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + 8 * 60 * 1000),
    });
  });
}

function associationData() {
  return {
    circleId: 'circle-1',
    pairingRequestId: pairingId,
    ownerUserId: 'adult-1',
    installationId,
    name: 'Android device',
    model: 'Not reported',
    platform: 'android',
    appVersion: '1.0.0',
    pairingStatus: 'paired',
    pairedAt: serverTimestamp(),
    lastSeenAt: serverTimestamp(),
    lastHeartbeatAt: serverTimestamp(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

test('authenticated installation registration is canonical and idempotent by path', async () => {
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  const ref = doc(adult, `users/adult-1/devices/${installationId}`);
  await assertSucceeds(setDoc(ref, installationData()));
  const devices = await assertSucceeds(getDocs(collection(adult, 'users/adult-1/devices')));
  assert.equal(devices.size, 1);
  await assertFails(setDoc(doc(adult, 'users/adult-1/devices/INVALID'), installationData()));
});

test('device ownership blocks reads, reassignment, malformed names and unauthenticated writes', async () => {
  await seedOldInstallation();
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  const outsider = testEnvironment.authenticatedContext('outsider-1').firestore();
  const anonymous = testEnvironment.unauthenticatedContext().firestore();
  const pathName = `users/adult-1/devices/${installationId}`;
  await assertSucceeds(getDoc(doc(adult, pathName)));
  await assertFails(getDoc(doc(outsider, pathName)));
  await assertFails(getDoc(doc(anonymous, pathName)));
  await assertFails(updateDoc(doc(adult, pathName), {ownerUserId: 'outsider-1'}));
  await assertFails(updateDoc(doc(adult, pathName), {name: 'x'.repeat(81), updatedAt: serverTimestamp()}));
});

test('pairing request is high entropy, short lived and tied to an active owned installation', async () => {
  await seedOldInstallation();
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  const expiresAt = Timestamp.fromMillis(Date.now() + 8 * 60 * 1000);
  const valid = {
    ownerUserId: 'adult-1',
    installationId,
    deviceName: 'Android device',
    platform: 'android',
    appVersion: '1.0.0',
    status: 'active',
    createdAt: serverTimestamp(),
    expiresAt,
  };
  await assertSucceeds(setDoc(doc(adult, `devicePairingRequests/${pairingId}`), valid));
  await assertFails(setDoc(doc(adult, 'devicePairingRequests/PAIR-1234'), valid));
  await assertFails(setDoc(doc(adult, 'devicePairingRequests/BCDEFGHJKLMNPQRSTUVWXY23'), {
    ...valid,
    ownerUserId: 'outsider-1',
  }));
  await assertFails(setDoc(doc(adult, 'devicePairingRequests/CDEFGHJKLMNPQRSTUVWXYZ2'), {
    ...valid,
    expiresAt: Timestamp.fromMillis(Date.now() + 20 * 60 * 1000),
  }));
});

test('manager consumes pairing token atomically and replay is denied', async () => {
  await seedOldInstallation();
  await seedPairingRequest();
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  const requestRef = doc(owner, `devicePairingRequests/${pairingId}`);
  const deviceRef = doc(owner, `groups/circle-1/devices/${associationId}`);
  const batch = writeBatch(owner);
  batch.set(deviceRef, associationData());
  batch.update(requestRef, {
    status: 'used',
    usedAt: serverTimestamp(),
    usedBy: 'owner-1',
    circleId: 'circle-1',
    deviceAssociationId: associationId,
    updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
  assert.equal((await getDoc(deviceRef)).data().ownerUserId, 'adult-1');

  const replay = writeBatch(owner);
  replay.set(deviceRef, associationData());
  replay.update(requestRef, {
    status: 'used',
    usedAt: serverTimestamp(),
    usedBy: 'owner-1',
    circleId: 'circle-1',
    deviceAssociationId: associationId,
    updatedAt: serverTimestamp(),
  });
  await assertFails(replay.commit());
});

test('wrong member, normal member and outsider cannot approve pairing', async () => {
  await seedOldInstallation('outsider-1');
  await seedPairingRequest('outsider-1');
  for (const actor of ['adult-1', 'outsider-1']) {
    const db = testEnvironment.authenticatedContext(actor).firestore();
    const batch = writeBatch(db);
    const wrongAssociation = `outsider-1_${installationId}`;
    batch.set(doc(db, `groups/circle-1/devices/${wrongAssociation}`), {
      ...associationData(),
      ownerUserId: 'outsider-1',
    });
    batch.update(doc(db, `devicePairingRequests/${pairingId}`), {
      status: 'used', usedAt: serverTimestamp(), usedBy: actor,
      circleId: 'circle-1', deviceAssociationId: wrongAssociation,
      updatedAt: serverTimestamp(),
    });
    await assertFails(batch.commit());
  }
});

test('heartbeat updates only the owned active device and is rate limited', async () => {
  await seedOldInstallation();
  await testEnvironment.withSecurityRulesDisabled(async context => {
    const old = Timestamp.fromMillis(Date.now() - 5 * 60 * 1000);
    await setDoc(doc(context.firestore(), `groups/circle-1/devices/${associationId}`), {
      ...associationData(),
      pairedAt: old,
      lastSeenAt: old,
      lastHeartbeatAt: old,
      createdAt: old,
      updatedAt: old,
    });
  });
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  const outsider = testEnvironment.authenticatedContext('outsider-1').firestore();
  const ownRef = doc(adult, `users/adult-1/devices/${installationId}`);
  const circleRef = doc(adult, `groups/circle-1/devices/${associationId}`);
  const update = {
    platform: 'android', appVersion: '1.0.0',
    lastSeenAt: serverTimestamp(), lastHeartbeatAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  const heartbeat = writeBatch(adult);
  heartbeat.update(ownRef, update);
  heartbeat.update(circleRef, update);
  await assertSucceeds(heartbeat.commit());
  await assertFails(updateDoc(ownRef, update));
  await assertFails(updateDoc(doc(outsider, `users/adult-1/devices/${installationId}`), update));
  await assertFails(updateDoc(doc(outsider, `groups/circle-1/devices/${associationId}`), update));
});

test('revoked installation cannot heartbeat and Circle unpair is a soft state', async () => {
  await seedOldInstallation();
  await testEnvironment.withSecurityRulesDisabled(async context => {
    const old = Timestamp.fromMillis(Date.now() - 5 * 60 * 1000);
    await setDoc(doc(context.firestore(), `groups/circle-1/devices/${associationId}`), {
      ...associationData(),
      pairedAt: old,
      lastSeenAt: old,
      lastHeartbeatAt: old,
      createdAt: old,
      updatedAt: old,
    });
  });
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  const ownRef = doc(adult, `users/adult-1/devices/${installationId}`);
  await assertSucceeds(updateDoc(ownRef, {
    status: 'revoked', pairingStatus: 'revoked', revokedAt: serverTimestamp(),
    revokedBy: 'adult-1', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(ownRef, {
    platform: 'android', appVersion: '1.0.0', lastSeenAt: serverTimestamp(),
    lastHeartbeatAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  const association = doc(owner, `groups/circle-1/devices/${associationId}`);
  await assertSucceeds(updateDoc(association, {
    pairingStatus: 'unpaired', removedAt: serverTimestamp(),
    removedBy: 'owner-1', updatedAt: serverTimestamp(),
  }));
  assert.equal((await getDoc(doc(owner, 'groups/circle-1'))).data().status, 'active');
});

test('device visibility is limited to owner and Circle managers', async () => {
  await testEnvironment.withSecurityRulesDisabled(async context => {
    const old = Timestamp.fromMillis(Date.now() - 5 * 60 * 1000);
    await setDoc(doc(context.firestore(), `groups/circle-1/devices/${associationId}`), {
      ...associationData(), pairedAt: old, lastSeenAt: old,
      lastHeartbeatAt: old, createdAt: old, updatedAt: old,
    });
  });
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  const outsider = testEnvironment.authenticatedContext('outsider-1').firestore();
  const ownerQuery = query(collection(owner, 'groups/circle-1/devices'), where('ownerUserId', '==', 'adult-1'));
  const selfQuery = query(collection(adult, 'groups/circle-1/devices'), where('ownerUserId', '==', 'adult-1'));
  await assertSucceeds(getDocs(ownerQuery));
  await assertSucceeds(getDocs(selfQuery));
  await assertFails(getDocs(collection(outsider, 'groups/circle-1/devices')));
});

test('screen-time writes are device-bound, idempotent and Circle scoped', async () => {
  await seedOldInstallation();
  await testEnvironment.withSecurityRulesDisabled(async context => {
    const old = Timestamp.fromMillis(Date.now() - 5 * 60 * 1000);
    await setDoc(doc(context.firestore(), `groups/circle-1/devices/${associationId}`), {
      ...associationData(), pairedAt: old, lastSeenAt: old,
      lastHeartbeatAt: old, createdAt: old, updatedAt: old,
    });
  });
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  const owner = testEnvironment.authenticatedContext('owner-1').firestore();
  const outsider = testEnvironment.authenticatedContext('outsider-1').firestore();
  const localDate = '2026-09-12';
  const record = {
    userId: 'adult-1', installationId, localDate,
    timeZoneOffsetMinutes: 300, totalTimeMs: 120000,
    apps: [{packageName: 'com.example.reader', appName: 'Reader', totalTimeMs: 120000}],
    collectedAt: Timestamp.now(), syncedAt: serverTimestamp(),
    source: 'android_usage_stats', schemaVersion: 1,
  };
  const ownRef = doc(adult, `users/adult-1/devices/${installationId}/screenTimeDaily/${localDate}`);
  const circleRef = doc(adult, `groups/circle-1/screenTimeDaily/adult-1_${installationId}_${localDate}`);
  await assertSucceeds(setDoc(ownRef, record));
  await assertSucceeds(setDoc(circleRef, record));
  await assertSucceeds(setDoc(circleRef, {...record, totalTimeMs: 180000}));
  await assertSucceeds(getDoc(doc(owner, circleRef.path)));
  await assertFails(getDoc(doc(outsider, circleRef.path)));
  await assertFails(setDoc(doc(outsider, circleRef.path), {...record, userId: 'outsider-1'}));
  await assertFails(setDoc(doc(adult, `groups/circle-1/screenTimeDaily/spoofed`), record));
});

test('only a device owner can publish screen-time permission and sync state', async () => {
  await seedOldInstallation();
  await testEnvironment.withSecurityRulesDisabled(async context => {
    const old = Timestamp.fromMillis(Date.now() - 5 * 60 * 1000);
    await setDoc(doc(context.firestore(), `groups/circle-1/devices/${associationId}`), {
      ...associationData(), pairedAt: old, lastSeenAt: old,
      lastHeartbeatAt: old, createdAt: old, updatedAt: old,
    });
  });
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  const outsider = testEnvironment.authenticatedContext('outsider-1').firestore();
  const ref = doc(adult, `users/adult-1/devices/${installationId}`);
  const association = doc(adult, `groups/circle-1/devices/${associationId}`);
  await assertSucceeds(updateDoc(ref, {
    permissions: {screenTime: false},
    screenTimePermissionState: 'notGranted',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(outsider, ref.path), {
    permissions: {screenTime: true},
    screenTimePermissionState: 'granted',
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(association, {
    permissions: {screenTime: false},
    screenTimePermissionState: 'notGranted',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(outsider, association.path), {
    permissions: {screenTime: true},
    screenTimePermissionState: 'granted',
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(ref, {
    permissions: {screenTime: true},
    lastScreenTimeSyncAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
});

test('push token is private to its installation and notification metadata mirrors to its Circle association', async () => {
  await seedOldInstallation();
  await testEnvironment.withSecurityRulesDisabled(async context => {
    const old = Timestamp.fromMillis(Date.now() - 5 * 60 * 1000);
    await setDoc(doc(context.firestore(), `groups/circle-1/devices/${associationId}`), {
      ...associationData(), pairedAt: old, lastSeenAt: old,
      lastHeartbeatAt: old, createdAt: old, updatedAt: old,
    });
  });
  const adult = testEnvironment.authenticatedContext('adult-1').firestore();
  const outsider = testEnvironment.authenticatedContext('outsider-1').firestore();
  const own = doc(adult, `users/adult-1/devices/${installationId}`);
  const metadata = {
    fcmToken: 'test-registration-token',
    notificationPermissionState: 'granted', notificationsEnabled: true,
    notificationCapable: true, manufacturer: 'Google', model: 'Pixel',
    osVersion: '16', androidApiLevel: 36, appVersion: '1.0.0',
    appBuildNumber: '1', pushUpdatedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
  await assertSucceeds(updateDoc(own, metadata));
  await assertFails(updateDoc(doc(outsider, own.path), {...metadata, fcmToken: 'stolen'}));
  const association = doc(adult, `groups/circle-1/devices/${associationId}`);
  const {fcmToken, ...publicMetadata} = metadata;
  await assertSucceeds(updateDoc(association, publicMetadata));
  await assertFails(updateDoc(association, {...publicMetadata, manufacturer: 'Spoofed'}));
  await assertSucceeds(updateDoc(own, {
    fcmToken: deleteField(), notificationsEnabled: false,
    pushUpdatedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
});
