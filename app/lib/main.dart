import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('USE EMULATOR IS $kUseEmulator');
    if (kUseEmulator) {
      await FirebaseAuth.instance.useAuthEmulator(kEmulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(kEmulatorHost, 8080);
      FirebaseFunctions.instanceFor(region: kFunctionsRegion).useFunctionsEmulator(kEmulatorHost, 5001);
    }
  } catch (e) {
    runApp(_StartupError('$e'));
    return;
  }
  runApp(const ProviderScope(child: MentorHubApp()));
}

class _StartupError extends StatelessWidget {
  const _StartupError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.settings_suggest_outlined, size: 48),
                const SizedBox(height: 12),
                const Text('MentorHub could not start', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}
