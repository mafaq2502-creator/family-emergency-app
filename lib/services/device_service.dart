import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/domain/device_policies.dart';
import '../models/device_pairing_request.dart';
import '../models/family_group.dart';
import '../models/paired_device.dart';

class DeviceException implements Exception {
  const DeviceException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

abstract interface class InstallationIdStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesInstallationIdStore implements InstallationIdStore {
  static const _key = 'device_installation_id_v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(_key, value);
}

class DeviceMetadata {
  const DeviceMetadata({
    required this.name,
    required this.platform,
    required this.appVersion,
  });
  final String name;
  final String platform;
  final String appVersion;

  factory DeviceMetadata.current() {
    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            TargetPlatform.macOS => 'macos',
            TargetPlatform.windows => 'windows',
            TargetPlatform.linux => 'linux',
            TargetPlatform.fuchsia => 'fuchsia',
          };
    final label = platform == 'ios'
        ? 'iOS'
        : platform[0].toUpperCase() + platform.substring(1);
    return DeviceMetadata(
      name: '$label device',
      platform: platform,
      appVersion: const String.fromEnvironment(
        'FLUTTER_BUILD_NAME',
        defaultValue: '1.0.0',
      ),
    );
  }
}

abstract interface class DeviceActions {
  Future<String> currentInstallationId();
  Future<PairedDevice> registerCurrentDevice();
  Stream<List<PairedDevice>> watchMyDevices();
  Stream<PairedDevice?> watchCurrentDevice();
  Stream<List<PairedDevice>> watchMemberDevices(
    String circleId,
    String ownerUserId,
  );
  Future<DevicePairingRequest> createPairingRequest();
  Future<void> revokePairingRequest(String code);
  Future<PairedDevice> pairDeviceToMember({
    required FamilyGroup group,
    required String targetUserId,
    required String code,
  });
  Future<void> heartbeat();
  Future<void> renameMyDevice(PairedDevice device, String name);
  Future<bool> revokeMyDevice(PairedDevice device);
  Future<void> unpairCircleDevice(String circleId, PairedDevice device);
}

class DeviceService implements DeviceActions {
  DeviceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    InstallationIdStore? installationStore,
    DeviceMetadata? metadata,
    Random? random,
    DateTime Function()? clock,
  }) : _providedFirestore = firestore,
       _providedAuth = auth,
       _installationStore =
           installationStore ?? SharedPreferencesInstallationIdStore(),
       _metadata = metadata ?? DeviceMetadata.current(),
       _random = random ?? Random.secure(),
       _clock = clock ?? (() => DateTime.now().toUtc());

  final FirebaseFirestore? _providedFirestore;
  final FirebaseAuth? _providedAuth;
  final InstallationIdStore _installationStore;
  final DeviceMetadata _metadata;
  final Random _random;
  final DateTime Function() _clock;
  String? _installationId;

  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw const DeviceException(
        'unauthenticated',
        'Please sign in again to manage devices.',
      );
    }
    return user;
  }

  @override
  Future<String> currentInstallationId() async {
    if (_installationId != null) return _installationId!;
    final stored = await _installationStore.read();
    if (stored != null && RegExp(r'^[A-Z2-9]{32}$').hasMatch(stored)) {
      return _installationId = stored;
    }
    final generated = _randomCode(
      DevicePolicy.installationIdLength,
      DevicePairingCodePolicy.alphabet,
    );
    await _installationStore.write(generated);
    return _installationId = generated;
  }

  DocumentReference<Map<String, dynamic>> _deviceRef(
    String userId,
    String installationId,
  ) => _firestore
      .collection('users')
      .doc(userId)
      .collection('devices')
      .doc(installationId);

  String _associationId(String userId, String installationId) =>
      '${userId}_$installationId';

  @override
  Future<PairedDevice> registerCurrentDevice() async {
    final user = _user;
    final installationId = await currentInstallationId();
    final reference = _deviceRef(user.uid, installationId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data?['status'] == 'revoked') {
        throw const DeviceException(
          'device-revoked',
          'This app installation was revoked for this account.',
        );
      }
      if (snapshot.exists) {
        final heartbeat = data?['lastHeartbeatAt'];
        if (heartbeat is Timestamp &&
            _clock().difference(heartbeat.toDate().toUtc()) <
                DevicePolicy.minimumHeartbeatInterval) {
          return;
        }
        transaction.update(reference, {
          'platform': _metadata.platform,
          'appVersion': _metadata.appVersion,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'lastHeartbeatAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(reference, {
          'installationId': installationId,
          'ownerUserId': user.uid,
          'name': _metadata.name,
          'platform': _metadata.platform,
          'appVersion': _metadata.appVersion,
          'status': 'active',
          'pairingStatus': DevicePairingStatus.registered.name,
          'registeredAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
          'lastHeartbeatAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    final snapshot = await reference.get();
    final data = snapshot.data();
    if (data == null) {
      throw const DeviceException(
        'registration-failed',
        'The device could not be registered.',
      );
    }
    return PairedDevice.fromMap(snapshot.id, data);
  }

  @override
  Stream<List<PairedDevice>> watchMyDevices() async* {
    final user = _user;
    final currentId = await currentInstallationId();
    yield* _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .snapshots()
        .map((snapshot) {
          final devices = snapshot.docs
              .map(
                (doc) => PairedDevice.fromMap(
                  doc.id,
                  doc.data(),
                ).copyWith(isCurrentDevice: doc.id == currentId),
              )
              .toList();
          devices.sort(
            (a, b) => (b.registeredAt ?? DateTime(0)).compareTo(
              a.registeredAt ?? DateTime(0),
            ),
          );
          return devices;
        });
  }

  @override
  Stream<PairedDevice?> watchCurrentDevice() async* {
    final user = _user;
    final id = await currentInstallationId();
    yield* _deviceRef(user.uid, id).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null
          ? null
          : PairedDevice.fromMap(
              snapshot.id,
              data,
            ).copyWith(isCurrentDevice: true);
    });
  }

  @override
  Stream<List<PairedDevice>> watchMemberDevices(
    String circleId,
    String ownerUserId,
  ) => _firestore
      .collection('groups')
      .doc(circleId)
      .collection('devices')
      .where('ownerUserId', isEqualTo: ownerUserId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => PairedDevice.fromMap(doc.id, doc.data()))
            .where(
              (device) => device.pairingStatus != DevicePairingStatus.unpaired,
            )
            .toList(),
      );

  @override
  Future<DevicePairingRequest> createPairingRequest() async {
    final user = _user;
    final device = await registerCurrentDevice();
    if (device.pairingStatus == DevicePairingStatus.revoked) {
      throw const DeviceException('device-revoked', 'This device is revoked.');
    }
    final code = _randomCode(
      DevicePolicy.pairingCodeLength,
      DevicePairingCodePolicy.alphabet,
    );
    final expiresAt = _clock().add(DevicePolicy.pairingLifetime);
    await _firestore.collection('devicePairingRequests').doc(code).set({
      'ownerUserId': user.uid,
      'installationId': device.installationId ?? device.id,
      'deviceName': device.name,
      'platform': device.platform,
      'appVersion': device.appVersion ?? _metadata.appVersion,
      'status': DevicePairingRequestStatus.active.name,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    return DevicePairingRequest(
      code: code,
      ownerUserId: user.uid,
      installationId: device.installationId ?? device.id,
      deviceName: device.name,
      platform: device.platform,
      appVersion: device.appVersion,
      status: DevicePairingRequestStatus.active,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> revokePairingRequest(String code) async {
    await _firestore
        .collection('devicePairingRequests')
        .doc(DevicePairingCodePolicy.normalize(code))
        .update({
          'status': DevicePairingRequestStatus.revoked.name,
          'revokedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<PairedDevice> pairDeviceToMember({
    required FamilyGroup group,
    required String targetUserId,
    required String code,
  }) async {
    final reviewer = _user;
    final validation = DevicePairingCodePolicy.validate(code);
    if (validation != null) throw DeviceException('invalid-code', validation);
    if (!group.canManage || !group.memberIds.contains(targetUserId)) {
      throw const DeviceException(
        'permission-denied',
        'You cannot pair a device for this member.',
      );
    }
    final normalized = DevicePairingCodePolicy.normalize(code);
    final requestRef = _firestore
        .collection('devicePairingRequests')
        .doc(normalized);
    return _firestore.runTransaction<PairedDevice>((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      final data = requestSnapshot.data();
      if (data == null) {
        throw const DeviceException(
          'invalid-code',
          'This pairing code is invalid or unavailable.',
        );
      }
      final request = DevicePairingRequest.fromMap(normalized, data);
      if (!request.isUsableAt(_clock()) ||
          request.ownerUserId != targetUserId) {
        throw const DeviceException(
          'invalid-code',
          'This pairing code is expired, used, or belongs to another member.',
        );
      }
      final associationId = _associationId(
        request.ownerUserId,
        request.installationId,
      );
      final deviceRef = _firestore
          .collection('groups')
          .doc(group.id)
          .collection('devices')
          .doc(associationId);
      final existing = await transaction.get(deviceRef);
      if (existing.data()?['pairingStatus'] == 'paired') {
        throw const DeviceException(
          'already-paired',
          'This device is already paired to the Circle.',
        );
      }
      final now = FieldValue.serverTimestamp();
      transaction.set(deviceRef, {
        'circleId': group.id,
        'pairingRequestId': normalized,
        'ownerUserId': request.ownerUserId,
        'installationId': request.installationId,
        'name': request.deviceName,
        'model': 'Not reported',
        'platform': request.platform,
        if (request.appVersion != null) 'appVersion': request.appVersion,
        'pairingStatus': DevicePairingStatus.paired.name,
        'pairedAt': now,
        'lastSeenAt': now,
        'lastHeartbeatAt': now,
        'createdAt': now,
        'updatedAt': now,
      });
      transaction.update(requestRef, {
        'status': DevicePairingRequestStatus.used.name,
        'usedAt': now,
        'usedBy': reviewer.uid,
        'circleId': group.id,
        'deviceAssociationId': associationId,
        'updatedAt': now,
      });
      return PairedDevice(
        id: associationId,
        installationId: request.installationId,
        circleId: group.id,
        userId: request.ownerUserId,
        name: request.deviceName,
        model: 'Not reported',
        platform: request.platform,
        appVersion: request.appVersion,
        pairingStatus: DevicePairingStatus.paired,
        pairedAt: _clock(),
        lastSeenAt: _clock(),
        lastHeartbeatAt: _clock(),
      );
    });
  }

  @override
  Future<void> heartbeat() async {
    final user = _user;
    final installationId = await currentInstallationId();
    final ownRef = _deviceRef(user.uid, installationId);
    final own = await ownRef.get();
    final ownData = own.data();
    if (ownData == null) {
      await registerCurrentDevice();
      return;
    }
    if (ownData['status'] == 'revoked') {
      throw const DeviceException('device-revoked', 'This device was revoked.');
    }
    final last = ownData['lastHeartbeatAt'];
    if (last is Timestamp &&
        _clock().difference(last.toDate().toUtc()) <
            DevicePolicy.minimumHeartbeatInterval) {
      return;
    }
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final circleIds = _strings(profile.data()?['circleIds']);
    final associationId = _associationId(user.uid, installationId);
    final associationRefs = circleIds
        .map(
          (circleId) => _firestore
              .collection('groups')
              .doc(circleId)
              .collection('devices')
              .doc(associationId),
        )
        .toList();
    final associationSnapshots = await Future.wait(
      associationRefs.map((reference) => reference.get()),
    );
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    batch.update(ownRef, {
      'platform': _metadata.platform,
      'appVersion': _metadata.appVersion,
      'lastSeenAt': now,
      'lastHeartbeatAt': now,
      'updatedAt': now,
    });
    for (var index = 0; index < associationRefs.length; index++) {
      final data = associationSnapshots[index].data();
      if (data != null && data['pairingStatus'] == 'paired') {
        batch.update(associationRefs[index], {
          'platform': _metadata.platform,
          'appVersion': _metadata.appVersion,
          'lastSeenAt': now,
          'lastHeartbeatAt': now,
          'updatedAt': now,
        });
      }
    }
    await batch.commit();
  }

  @override
  Future<void> renameMyDevice(PairedDevice device, String name) async {
    final validation = DevicePolicy.validateName(name);
    if (validation != null) throw DeviceException('invalid-name', validation);
    final user = _user;
    if (device.userId != user.uid) {
      throw const DeviceException(
        'permission-denied',
        'You can rename only your own device.',
      );
    }
    final installationId = device.installationId ?? device.id;
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final circleIds = _strings(profile.data()?['circleIds']);
    final associationId = _associationId(user.uid, installationId);
    final associationRefs = circleIds
        .map(
          (circleId) => _firestore
              .collection('groups')
              .doc(circleId)
              .collection('devices')
              .doc(associationId),
        )
        .toList();
    final existing = await Future.wait(
      associationRefs.map((reference) => reference.get()),
    );
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    batch.update(_deviceRef(user.uid, installationId), {
      'name': name.trim(),
      'updatedAt': now,
    });
    for (var index = 0; index < associationRefs.length; index++) {
      if (existing[index].exists) {
        batch.update(associationRefs[index], {
          'name': name.trim(),
          'updatedAt': now,
        });
      }
    }
    await batch.commit();
  }

  @override
  Future<bool> revokeMyDevice(PairedDevice device) async {
    final user = _user;
    if (device.userId != user.uid) {
      throw const DeviceException(
        'permission-denied',
        'You can revoke only your own device.',
      );
    }
    final installationId = device.installationId ?? device.id;
    final current = await currentInstallationId();
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final circleIds = _strings(profile.data()?['circleIds']);
    final associationId = _associationId(user.uid, installationId);
    final associationRefs = circleIds
        .map(
          (circleId) => _firestore
              .collection('groups')
              .doc(circleId)
              .collection('devices')
              .doc(associationId),
        )
        .toList();
    final existing = await Future.wait(
      associationRefs.map((reference) => reference.get()),
    );
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    batch.update(_deviceRef(user.uid, installationId), {
      'status': 'revoked',
      'pairingStatus': DevicePairingStatus.revoked.name,
      'revokedAt': now,
      'revokedBy': user.uid,
      'updatedAt': now,
    });
    for (var index = 0; index < associationRefs.length; index++) {
      if (existing[index].exists) {
        batch.update(associationRefs[index], {
          'pairingStatus': DevicePairingStatus.revoked.name,
          'revokedAt': now,
          'revokedBy': user.uid,
          'updatedAt': now,
        });
      }
    }
    await batch.commit();
    return installationId == current;
  }

  @override
  Future<void> unpairCircleDevice(String circleId, PairedDevice device) =>
      _firestore
          .collection('groups')
          .doc(circleId)
          .collection('devices')
          .doc(device.id)
          .update({
            'pairingStatus': DevicePairingStatus.unpaired.name,
            'removedAt': FieldValue.serverTimestamp(),
            'removedBy': _user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

  String _randomCode(int length, String alphabet) => List.generate(
    length,
    (_) => alphabet[_random.nextInt(alphabet.length)],
  ).join();

  static List<String> _strings(Object? value) => value is List
      ? value.whereType<String>().where((item) => item.isNotEmpty).toList()
      : const [];
}

extension PairedDeviceCopy on PairedDevice {
  PairedDevice copyWith({bool? isCurrentDevice}) => PairedDevice(
    id: id,
    userId: userId,
    name: name,
    model: model,
    platform: platform,
    pairingStatus: pairingStatus,
    installationId: installationId,
    circleId: circleId,
    osVersion: osVersion,
    appVersion: appVersion,
    isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
    batteryLevel: batteryLevel,
    storageUsedPercent: storageUsedPercent,
    lastSeenAt: lastSeenAt,
    lastHeartbeatAt: lastHeartbeatAt,
    registeredAt: registeredAt,
    pairedAt: pairedAt,
    updatedAt: updatedAt,
    revokedAt: revokedAt,
    removedAt: removedAt,
    permissions: permissions,
  );
}
