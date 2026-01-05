import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showWarning(String message) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fraud_alerts',
      'Fraud Alerts',
      channelDescription: '🚨 Critical alerts for scam detections',
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFFFF0000), 
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'mark_spam',
          'Report as Spam',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
      styleInformation: BigTextStyleInformation(
        message,
        contentTitle: '🚨 FRAUD DETECTED!',
        summaryText: 'Action Required',
      ),
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      '🚨 FRAUD DETECTED!',
      message,
      platformDetails,
    );
  }

  static Future<void> showScanResult(String message, String label, double confidence) async {
    final bool isFraud = label == "Fraud/Spam";
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'scan_results',
      'Scan Status',
      channelDescription: 'Immediate status of incoming messages',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: isFraud ? const Color(0xFFFF0000) : const Color(0xFF4CAF50),
      playSound: !isFraud, // Don't annoy for safe messages, just show
      styleInformation: BigTextStyleInformation(
        message,
        contentTitle: isFraud ? '🚩 SPAM DETECTED' : '🛡️ VERIFIED SAFE',
        summaryText: isFraud ? 'Risk Level: High' : 'Secure Message',
      ),
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecond + 1,
      isFraud ? '🚩 Spam Alert' : '🛡️ Verified Safe',
      message,
      platformDetails,
    );
  }
}
