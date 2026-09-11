import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/domain/device_policies.dart';
import '../models/paired_device.dart';
import 'device_service.dart';

class DeviceHeartbeatController with WidgetsBindingObserver {
  DeviceHeartbeatController({DeviceActions? service})
    : _service = service ?? DeviceService();

  final DeviceActions _service;
  Timer? _timer;
  StreamSubscription<PairedDevice?>? _deviceSubscription;
  bool _running = false;
  bool _pulseInProgress = false;
  Future<void> Function()? _onCurrentDeviceRevoked;

  Future<void> start({Future<void> Function()? onCurrentDeviceRevoked}) async {
    if (_running) return;
    _running = true;
    _onCurrentDeviceRevoked = onCurrentDeviceRevoked;
    WidgetsBinding.instance.addObserver(this);
    _watchRevocation();
    try {
      await _service.registerCurrentDevice();
    } catch (_) {
      // Network/auth errors retry at the normal interval and never block startup.
    }
    _schedule();
  }

  void _watchRevocation() {
    _deviceSubscription?.cancel();
    _deviceSubscription = _service.watchCurrentDevice().listen((device) async {
      if (device?.pairingStatus == DevicePairingStatus.revoked) {
        _timer?.cancel();
        await _onCurrentDeviceRevoked?.call();
      }
    }, onError: (_) {});
  }

  void _schedule() {
    _timer?.cancel();
    if (!_running) return;
    _timer = Timer.periodic(DevicePolicy.heartbeatInterval, (_) => _pulse());
  }

  Future<void> _pulse() async {
    if (!_running || _pulseInProgress) return;
    _pulseInProgress = true;
    try {
      await _service.heartbeat();
    } on DeviceException catch (error) {
      if (error.code == 'device-revoked') {
        _timer?.cancel();
        await _onCurrentDeviceRevoked?.call();
      }
    } catch (_) {
      // The next scheduled foreground heartbeat is the bounded retry.
    } finally {
      _pulseInProgress = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      _pulse();
      _schedule();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
    }
  }

  Future<void> dispose() async {
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    await _deviceSubscription?.cancel();
  }
}
