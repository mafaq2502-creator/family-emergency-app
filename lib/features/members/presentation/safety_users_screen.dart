import 'package:cloud_functions/cloud_functions.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/light_ui.dart';
import '../../../core/widgets/mobile_phone_field.dart';
import '../../../core/domain/mobile_phone_number.dart';
import '../../../services/safety_user_service.dart';
import '../../../models/notification_settings.dart';
import '../../shell/presentation/tabs/plan_tab.dart';

Future<bool> safetyAction(
  BuildContext context,
  Future<dynamic> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FirebaseFunctionsException
                ? error.message ?? 'Please try again.'
                : 'Could not complete the request. Please try again.',
          ),
        ),
      );
    }
    return false;
  }
}

class SafetyUsersScreen extends StatefulWidget {
  const SafetyUsersScreen({
    super.key,
    this.service,
    this.initialRequests = false,
    this.embedded = false,
  });
  final bool initialRequests;
  final bool embedded;
  final SafetyUserService? service;
  @override
  State<SafetyUsersScreen> createState() => _SafetyUsersScreenState();
}

class _SafetyUsersScreenState extends State<SafetyUsersScreen> {
  late final service = widget.service ?? SafetyUserService();
  late final stream = service.users();
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: widget.initialRequests ? 1 : 0,
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: widget.embedded ? 0 : null,
        title: const Text('Users'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Users List'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddSafetyUserScreen(service: service),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Add New User'),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Unable to load Users. Please try again.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = snapshot.data!;
                    if (users.isEmpty) {
                      return const Center(child: Text('No Added Users yet.'));
                    }
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '${users.length} active or reserved users',
                          ),
                        ),
                        for (final user in users)
                          ListTile(
                            leading: LightAvatar(
                              name: user['name'] as String,
                              photoUrl: user['photoUrl'] as String?,
                            ),
                            title: Text(user['name'] as String),
                            subtitle: Text(
                              user['status'] == 'connected'
                                  ? 'Connected'
                                  : 'Pending',
                            ),
                            trailing: Icon(
                              user['status'] == 'connected'
                                  ? Icons.check_circle
                                  : Icons.schedule,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SafetyUserDetailScreen(
                                  id: user['id'] as String,
                                  service: service,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          SafetyRequestsView(service: service),
        ],
      ),
    ),
  );
}

class SafetyRequestsView extends StatefulWidget {
  const SafetyRequestsView({super.key, this.service, this.circle = false});
  final bool circle;
  final SafetyUserService? service;
  @override
  State<SafetyRequestsView> createState() => _SafetyRequestsViewState();
}

class _SafetyRequestsViewState extends State<SafetyRequestsView> {
  late final service = widget.service ?? SafetyUserService();
  late final stream = service.requests(circle: widget.circle);
  final Set<String> busy = {};
  Future<void> respond(String id, bool accept) async {
    setState(() => busy.add(id));
    await safetyAction(
      context,
      () => service.call(
        widget.circle ? 'respondDirectCircleInvite' : 'respondSafetyInvite',
        {'invitationId': id, 'accept': accept},
      ),
    );
    if (mounted) setState(() => busy.remove(id));
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Could not load requests. Check your connection and verified email.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final invite in snapshot.data!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LightCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: LightAvatar(
                            name: '${invite['senderName'] ?? 'Circle owner'}',
                            photoUrl: invite['senderPhotoUrl'] as String?,
                          ),
                          title: Text(
                            '${invite['senderName'] ?? 'Circle owner'}',
                          ),
                          subtitle: Text(
                            widget.circle
                                ? 'Invited you to ${invite['circleName']}'
                                : 'Wants to add you',
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: busy.contains(invite['id'])
                                    ? null
                                    : () => respond(invite['id'], true),
                                child: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: busy.contains(invite['id'])
                                    ? null
                                    : () => respond(invite['id'], false),
                                child: const Text('Decline'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class AddSafetyUserScreen extends StatefulWidget {
  const AddSafetyUserScreen({super.key, this.service});
  final SafetyUserService? service;
  @override
  State<AddSafetyUserScreen> createState() => _AddSafetyUserScreenState();
}

class _AddSafetyUserScreenState extends State<AddSafetyUserScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController();
  Country country = Country.parse('PK');
  String? relationship;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    Map<String, dynamic>? result;
    final success = await safetyAction(context, () async {
      result = await (widget.service ?? SafetyUserService()).call(
        'inviteSafetyUser',
        {
          'name': name.text.trim(),
          'email': email.text.trim(),
          'phone': MobilePhoneNumber.normalize(phone.text, country.phoneCode),
          'relationship': relationship,
        },
      );
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?['emailStatus'] == 'configuration-required'
                ? 'Request created. Email delivery needs configuration.'
                : 'Request created. Email delivery queued.',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add New User')),
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'User Name'),
              validator: (value) =>
                  (value?.trim().length ?? 0) < 2 ? 'Enter a name.' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid email.',
            ),
            const SizedBox(height: 20),
            MobilePhoneField(
              controller: phone,
              country: country,
              onCountryChanged: (value) => setState(() => country = value),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: relationship,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Relationship'),
              items:
                  const [
                        'Father',
                        'Mother',
                        'Son',
                        'Daughter',
                        'Husband',
                        'Wife',
                        'Grandfather',
                        'Grandmother',
                        'Grandson',
                        'Granddaughter',
                        'Brother',
                        'Sister',
                      ]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => relationship = value),
              validator: (value) =>
                  value == null ? 'Choose a relationship.' : null,
            ),
            const SizedBox(height: 24),
            AppActionLayout(
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy ? null : send,
                  child: Text(busy ? 'Sending…' : 'Send Invite'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class SafetyUserDetailScreen extends StatefulWidget {
  const SafetyUserDetailScreen({super.key, this.service, required this.id});
  final String id;
  final SafetyUserService? service;
  @override
  State<SafetyUserDetailScreen> createState() => _SafetyUserDetailScreenState();
}

class _SafetyUserDetailScreenState extends State<SafetyUserDetailScreen> {
  late final service = widget.service ?? SafetyUserService();
  late final stream = service.detail(widget.id);
  bool busy = false;
  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('Remove User?'),
        content: const Text(
          'This removes the user from your Users List, deletes your saved relationship details and notification preferences, and removes them from all Circles you own. Their account and other owners’ Circles remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    final success = await safetyAction(
      context,
      () => service.call('removeSafetyUser', {'relationshipId': widget.id}),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>?>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          !snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final data = snapshot.hasError ? null : snapshot.data;
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Detail'),
          actions: [
            if (data?['ownerId'] == service.uid)
              IconButton(
                tooltip: 'Remove User',
                onPressed: busy ? null : remove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: data == null || data['ownerId'] != service.uid
            ? Center(
                child: Text(
                  snapshot.hasError
                      ? 'User details unavailable.'
                      : 'User is no longer available.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  LightAvatar(
                    name: data['name'],
                    photoUrl: data['photoUrl'] as String?,
                  ),
                  const SizedBox(height: 16),
                  for (final entry in {
                    'Name': data['name'],
                    'Email': data['email'],
                    'Mobile Number': data['phone'],
                    'Relationship': data['relationship'],
                    'Status': data['status'] == 'connected'
                        ? 'Connected'
                        : 'Pending',
                  }.entries)
                    ListTile(
                      title: Text(entry.key),
                      subtitle: Text('${entry.value ?? ''}'),
                    ),
                  if (data['status'] == 'connected')
                    ListTile(
                      title: const Text('Notification Settings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SafetyPreferencesScreen(
                            id: widget.id,
                            service: service,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      );
    },
  );
}

class SafetyPreferencesScreen extends StatefulWidget {
  const SafetyPreferencesScreen({super.key, this.service, required this.id});
  final String id;
  final SafetyUserService? service;
  @override
  State<SafetyPreferencesScreen> createState() =>
      _SafetyPreferencesScreenState();
}

class _SafetyPreferencesScreenState extends State<SafetyPreferencesScreen> {
  late final service = widget.service ?? SafetyUserService();
  late final stream = service.detail(widget.id);
  late final profile = service.profile();
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('User Notification Settings')),
    body: StreamBuilder<Map<String, dynamic>>(
      stream: profile,
      builder: (context, owner) {
        if (owner.hasError) {
          return const Center(child: Text('User settings unavailable.'));
        }
        final premium =
            owner.data?['planTier'] == 'premium' &&
            owner.data?['subscriptionStatus'] == 'active';
        return StreamBuilder<Map<String, dynamic>?>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('User settings unavailable.'));
            }
            final data = snapshot.data;
            if (data == null ||
                data['ownerId'] != service.uid ||
                data['status'] != 'connected') {
              return const Center(child: Text('Active relationship required.'));
            }
            final prefs = Map<String, dynamic>.from(
              data['notificationPreferences'] as Map? ?? {},
            );
            return ListView(
              children: [
                for (final category in safetyNotificationCategories.entries)
                  SwitchListTile(
                    title: Text(category.value),
                    subtitle: !premium && category.key != 'emergencyAlerts'
                        ? const Text('Premium')
                        : null,
                    value:
                        (premium || category.key == 'emergencyAlerts') &&
                        prefs[category.key] == true,
                    onChanged: busy
                        ? null
                        : (value) async {
                            if (!premium && category.key != 'emergencyAlerts') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PlansScreen(),
                                ),
                              );
                              return;
                            }
                            final next = {
                              for (final key
                                  in safetyNotificationCategories.keys)
                                key:
                                    (premium || key == 'emergencyAlerts') &&
                                    prefs[key] == true,
                              category.key: value,
                            };
                            setState(() => busy = true);
                            await safetyAction(
                              context,
                              () => service.call('updateSafetyPreferences', {
                                'relationshipId': widget.id,
                                'preferences': next,
                              }),
                            );
                            if (mounted) setState(() => busy = false);
                          },
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}

class InviteSafetyUserToCircleScreen extends StatefulWidget {
  const InviteSafetyUserToCircleScreen({
    super.key,
    this.service,
    required this.circleId,
  });
  final String circleId;
  final SafetyUserService? service;
  @override
  State<InviteSafetyUserToCircleScreen> createState() =>
      _InviteSafetyUserToCircleScreenState();
}

class _InviteSafetyUserToCircleScreenState
    extends State<InviteSafetyUserToCircleScreen> {
  late final service = widget.service ?? SafetyUserService();
  late Future<Map<String, dynamic>> candidates = service.call(
    'listCircleSafetyCandidates',
    {'circleId': widget.circleId},
  );
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invite User')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: candidates,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => candidates = service.call('listCircleSafetyCandidates', {
                  'circleId': widget.circleId,
                }),
              ),
              child: const Text('Could not load users. Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = List<Map<String, dynamic>>.from(
          (snapshot.data!['candidates'] as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        return ListView(
          children: [
            if (users.isEmpty)
              const ListTile(
                title: Text('Add and connect a Safety User first.'),
              ),
            for (final data in users)
              ListTile(
                title: Text(data['name']),
                subtitle: data['reason'] == null ? null : Text(data['reason']),
                trailing: TextButton(
                  onPressed: busy || data['eligible'] != true
                      ? null
                      : () async {
                          setState(() => busy = true);
                          Map<String, dynamic>? result;
                          final success = await safetyAction(context, () async {
                            result = await service.call('createCircleInvite', {
                              'circleId': widget.circleId,
                              'relationshipId': data['id'],
                            });
                          });
                          if (!context.mounted) return;
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result?['emailStatus'] ==
                                          'configuration-required'
                                      ? 'Invitation created. Email configuration required.'
                                      : 'Invitation created. Email queued.',
                                ),
                              ),
                            );
                          }
                          setState(() {
                            busy = false;
                            candidates = service.call(
                              'listCircleSafetyCandidates',
                              {'circleId': widget.circleId},
                            );
                          });
                        },
                  child: const Text('Invite'),
                ),
              ),
          ],
        );
      },
    ),
  );
}
