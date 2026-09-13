import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'app/family_emergency_app.dart';
import 'core/theme/theme_mode_controller.dart';
import 'services/screen_time_service.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeThemeMode();
  await initializeScreenTimeBackgroundSync();
  runApp(const FirebaseBootstrapApp());
}

class FirebaseBootstrapApp extends StatefulWidget {
  const FirebaseBootstrapApp({super.key});

  @override
  State<FirebaseBootstrapApp> createState() => _FirebaseBootstrapAppState();
}

class _FirebaseBootstrapAppState extends State<FirebaseBootstrapApp> {
  static const _testEntitlements =
      kDebugMode && bool.fromEnvironment('ENABLE_TEST_ENTITLEMENTS');
  Future<FirebaseApp> _initialize() async {
    if (!_testEntitlements) return Firebase.initializeApp();
    final app = await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-key',
        appId: '1:000000000000:android:0000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'demo-alivecircle',
      ),
    );
    const host = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '10.0.2.2',
    );
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    return app;
  }

  late Future<FirebaseApp> _initialization = _initialize();

  void _retry() {
    setState(() => _initialization = _initialize());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FirebaseApp>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      }
      if (snapshot.hasError) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 52),
                      const SizedBox(height: 16),
                      const Text(
                        'The app could not connect to Firebase.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return FutureBuilder<void>(
        future: _testEntitlements
            ? Future<void>.value()
            : PushNotificationService.instance.initialize(),
        builder: (_, _) => const FamilyEmergencyApp(),
      );
    },
  );
}
