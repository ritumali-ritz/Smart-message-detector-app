import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/sms_service.dart';
import 'services/notification_service.dart';
import 'screens/dashboard.dart';
import 'package:another_telephony/telephony.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Critical for logging)
  try {
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  // Initialize Notifications
  await NotificationService.init();

  // Listen for notification actions
  FlutterLocalNotificationsPlugin().initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: (response) {
      if (response.payload != null || response.actionId == 'mark_spam') {
        print("Notification Action Triggered: ${response.actionId}");
        // Here we could add logic to blacklist the sender in Firestore
      }
    },
  );

  // Initialize SMS Service & Predictions
  final smsService = SmsService();
  await smsService.init(); 
  
  // Start Listening immediately
  // NOTE: backgroundSmsHandler must be a static/top-level function (it is, in sms_service.dart)
  smsService.startListening();

  runApp(const FraudShieldApp());
}

class FraudShieldApp extends StatelessWidget {
  const FraudShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FraudShield',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
