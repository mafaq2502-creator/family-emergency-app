import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/light_ui.dart';
import '../../notifications/presentation/notification_bell_button.dart';
import '../../../models/screen_time.dart';
import '../../../services/screen_time_service.dart';

const progressPeriods = ['Today', 'Yesterday', 'Last week', 'Last month'];

class ScreenTimeOverviewCard extends StatefulWidget {
  const ScreenTimeOverviewCard({
    super.key,
    required this.circleId,
    required this.memberUserId,
    required this.periodLabel,
    required this.onTap,
    this.service,
  });
  final String? circleId;
  final String? memberUserId;
  final String periodLabel;
  final VoidCallback onTap;
  final ScreenTimeService? service;

  @override
  State<ScreenTimeOverviewCard> createState() => _ScreenTimeOverviewCardState();
}

class _ScreenTimeOverviewCardState extends State<ScreenTimeOverviewCard> {
  late final ScreenTimeService _service = widget.service ?? ScreenTimeService();
  Future<ScreenTimeSummary>? _summary;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant ScreenTimeOverviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.circleId != widget.circleId ||
        oldWidget.memberUserId != widget.memberUserId ||
        oldWidget.periodLabel != widget.periodLabel) {
      _reload();
    }
  }

  void _reload() {
    final circleId = widget.circleId;
    _summary = circleId == null
        ? null
        : _service.loadCircleSummary(
            circleId: circleId,
            userId: widget.memberUserId,
            period: ScreenTimePeriodX.fromLabel(widget.periodLabel),
          );
  }

  @override
  Widget build(BuildContext context) => LightCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<ScreenTimeSummary>(
          future: _summary,
          builder: (context, snapshot) {
            final summary = snapshot.data;
            final value = widget.circleId == null
                ? 'Select a Circle'
                : snapshot.connectionState != ConnectionState.done
                ? 'Loading…'
                : snapshot.hasError
                ? 'Sync unavailable'
                : summary == null || summary.totalTime == Duration.zero
                ? 'No data'
                : formatScreenTime(summary.totalTime);
            final message = summary?.lastSyncedAt == null
                ? 'Open details to enable, sync, or review Android usage.'
                : '${summary!.deviceCount} device${summary.deviceCount == 1 ? '' : 's'} • ${widget.periodLabel}';
            return Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.appSuccessSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: context.appPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Screen Time',
                        style: TextStyle(
                          color: context.appMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          color: context.appHeading,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(color: context.appMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class ProgressPeriodSelector extends StatelessWidget {
  const ProgressPeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 7,
    runSpacing: 7,
    children: progressPeriods
        .map(
          (period) => ChoiceChip(
            label: Text(period),
            selected: period == value,
            onSelected: (_) => onChanged(period),
            selectedColor: context.appPrimary,
            labelStyle: TextStyle(
              color: period == value ? Colors.white : context.appMuted,
              fontSize: AppTypography.tabLabel,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide.none,
          ),
        )
        .toList(),
  );
}

class ScreenTimeDetailScreen extends StatefulWidget {
  const ScreenTimeDetailScreen({
    super.key,
    this.memberName = 'All members',
    this.circleId,
    this.memberUserId,
    this.service,
  });
  final String memberName;
  final String? circleId;
  final String? memberUserId;
  final ScreenTimeService? service;

  @override
  State<ScreenTimeDetailScreen> createState() => _ScreenTimeDetailScreenState();
}

class _ScreenTimeDetailScreenState extends State<ScreenTimeDetailScreen>
    with WidgetsBindingObserver {
  String _period = 'Today';
  late final ScreenTimeService _service = widget.service ?? ScreenTimeService();
  ScreenTimePermissionState _permission = ScreenTimePermissionState.unknown;
  ScreenTimeSummary? _summary;
  bool _loading = true;
  bool _syncing = false;
  bool _hasConsent = false;
  String? _error;

  bool get _isOwnSelection {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return false;
    }
    return uid != null &&
        (widget.memberUserId == null || widget.memberUserId == uid);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isOwnSelection) {
      _load(sync: true);
    }
  }

  Future<void> _load({bool sync = false}) async {
    final circleId = widget.circleId;
    if (circleId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Select a Circle first.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final permission = _isOwnSelection
          ? await _service.permissionState()
          : ScreenTimePermissionState.unknown;
      final hasConsent = !_isOwnSelection || await _service.hasConsent();
      if (sync && permission == ScreenTimePermissionState.granted) {
        await _service.syncCurrentDevice(
          period: ScreenTimePeriodX.fromLabel(_period),
        );
      }
      final summary = await _service.loadCircleSummary(
        circleId: circleId,
        userId: widget.memberUserId,
        period: ScreenTimePeriodX.fromLabel(_period),
      );
      if (mounted) {
        setState(() {
          _permission = permission;
          _hasConsent = hasConsent;
          _summary = summary;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _syncing = false;
        });
      }
    }
  }

  Future<void> _requestAccess() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share screen time?'),
        content: const Text(
          'SafeCircle will read Android app-usage totals and share them with members of your paired Circles. You can turn Usage access off at any time in Android Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await _service.recordConsent();
    final permission = await _service.permissionState();
    if (permission == ScreenTimePermissionState.granted) {
      if (mounted) setState(() => _hasConsent = true);
      await _refresh();
      return;
    }
    final opened = await _service.openUsageAccessSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Android Usage access settings could not be opened.'),
        ),
      );
    }
  }

  Future<void> _refresh() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    await _load(sync: _isOwnSelection);
  }

  @override
  Widget build(BuildContext context) => LightPage(
    title: 'Screen Time',
    subtitle: widget.memberName,
    actions: const [NotificationBellButton()],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressPeriodSelector(
          value: _period,
          onChanged: (value) {
            setState(() => _period = value);
            _load();
          },
        ),
        const SizedBox(height: 18),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_isOwnSelection &&
            _permission == ScreenTimePermissionState.unavailable)
          const LightStateView(
            icon: Icons.phonelink_off_rounded,
            title: 'Not available on this device',
            message: 'Screen-time collection is currently supported on Android devices only.',
          )
        else if (_isOwnSelection &&
            (_permission != ScreenTimePermissionState.granted || !_hasConsent))
          LightStateView(
            icon: Icons.admin_panel_settings_outlined,
            title: !_hasConsent
                ? 'Screen-time sharing is off'
                : 'Usage access required',
            message: !_hasConsent
                ? 'Review what SafeCircle shares with members of your paired Circles before enabling collection.'
                : 'Android requires you to enable special Usage access before SafeCircle can read real app-usage totals.',
            actionLabel: !_hasConsent
                ? 'Review and Continue'
                : 'Open Usage Access',
            onAction: _requestAccess,
          )
        else if (_error != null)
          LightStateView(
            icon: Icons.sync_problem_rounded,
            title: 'Could not load screen time',
            message: _error!,
          )
        else if ((_summary?.totalTime ?? Duration.zero) == Duration.zero)
          LightStateView(
            icon: Icons.schedule_rounded,
            title: 'No usage recorded',
            message:
                'No real Android usage was recorded for ${widget.memberName} in $_period. A paired device must sync before another member can view it.',
          )
        else
          LightCard(
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: kEmerald, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatScreenTime(_summary!.totalTime),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        '${_summary!.deviceCount} device${_summary!.deviceCount == 1 ? '' : 's'} • $_period',
                        style: TextStyle(color: context.appMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _syncing ? null : _refresh,
                  tooltip: 'Refresh screen time',
                  icon: _syncing
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        const LightSectionTitle('App Usage'),
        if ((_summary?.apps ?? const []).isEmpty)
          LightCard(
            child: Text(
              'No app usage is available for this selection.',
              style: TextStyle(color: context.appMuted),
            ),
          )
        else
          ..._summary!.apps
              .take(20)
              .map(
                (app) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LightCard(
                    child: Row(
                      children: [
                        const Icon(Icons.apps_rounded, color: kEmerald),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            app.appName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatScreenTime(app.totalTime),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        if (_summary?.lastSyncedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'Last synced ${_summary!.lastSyncedAt!.toLocal()}',
                style: TextStyle(color: context.appMuted, fontSize: 12),
              ),
            ),
          ),
      ],
    ),
  );
}

class CheckInHistoryScreen extends StatefulWidget {
  const CheckInHistoryScreen({
    super.key,
    this.memberName = 'All members',
    this.latestCheckIn,
  });
  final String memberName;
  final DateTime? latestCheckIn;

  @override
  State<CheckInHistoryScreen> createState() => _CheckInHistoryScreenState();
}

class _CheckInHistoryScreenState extends State<CheckInHistoryScreen> {
  String _period = 'Today';

  @override
  Widget build(BuildContext context) {
    final checkIn = widget.latestCheckIn;
    return LightPage(
      title: 'Check-In History',
      subtitle: widget.memberName,
      actions: const [NotificationBellButton()],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressPeriodSelector(
            value: _period,
            onChanged: (value) => setState(() => _period = value),
          ),
          const SizedBox(height: 18),
          if (checkIn != null && _period == 'Today')
            LightCard(
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: kEmerald),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latest check-in',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          MaterialLocalizations.of(context)
                              .formatTimeOfDay(TimeOfDay.fromDateTime(checkIn)),
                          style: TextStyle(
                            color: context.appMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const LightStatusChip(label: 'Checked in'),
                ],
              ),
            )
          else
            LightStateView(
              icon: Icons.event_note_rounded,
              title: 'No history available',
              message: _period == 'Today'
                  ? 'No check-in has been recorded for this selection today.'
                  : 'Historical check-in storage is not connected for $_period.',
            ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Times are displayed in the device’s local timezone.',
              style: TextStyle(color: context.appMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressDetailsScreen extends StatelessWidget {
  const ProgressDetailsScreen({
    super.key,
    this.memberName = 'All members',
    this.latestCheckIn,
    this.circleId,
    this.memberUserId,
  });
  final String memberName;
  final DateTime? latestCheckIn;
  final String? circleId;
  final String? memberUserId;

  @override
  Widget build(BuildContext context) => LightPage(
    title: 'Progress Details',
    subtitle: memberName,
    actions: const [NotificationBellButton()],
    child: Column(
      children: [
        LightSettingRow(
          icon: Icons.schedule_rounded,
          title: 'Screen Time',
          subtitle: 'Usage appears only after supported device telemetry',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScreenTimeDetailScreen(
                memberName: memberName,
                circleId: circleId,
                memberUserId: memberUserId,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        LightSettingRow(
          icon: Icons.verified_rounded,
          title: 'Check-In History',
          subtitle: latestCheckIn == null
              ? 'No check-in is available'
              : 'Latest check-in is available',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CheckInHistoryScreen(
                memberName: memberName,
                latestCheckIn: latestCheckIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const LightStateView(
          icon: Icons.insights_rounded,
          title: 'Device progress is not connected',
          message: 'Battery, storage and usage need a paired device with explicit sharing consent.',
        ),
      ],
    ),
  );
}
