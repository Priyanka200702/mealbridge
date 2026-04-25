import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ngofood/firebase_options.dart';
import 'package:ngofood/services/notification_service.dart';
import 'package:ngofood/onboard.dart';
import 'package:ngofood/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notifications
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NGOFood',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const OnboardingPage(),
    );
  }
}
