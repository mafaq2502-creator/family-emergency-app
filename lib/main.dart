import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/family_emergency_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FirebaseBootstrapApp());
}

class FirebaseBootstrapApp extends StatefulWidget {
  const FirebaseBootstrapApp({super.key});

  @override
  State<FirebaseBootstrapApp> createState() => _FirebaseBootstrapAppState();
}

class _FirebaseBootstrapAppState extends State<FirebaseBootstrapApp> {
  late Future<FirebaseApp> _initialization = Firebase.initializeApp();

  void _retry() {
    setState(() => _initialization = Firebase.initializeApp());
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
      return const FamilyEmergencyApp();
    },
  );
}
