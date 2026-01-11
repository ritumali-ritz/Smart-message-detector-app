import 'package:another_telephony/telephony.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'ml_service.dart';
import 'notification_service.dart';
import 'block_list_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@pragma('vm:entry-point')
void backgrounSmsHandler(SmsMessage message) async {
  print("Background SMS Received: ${message.body}");
  
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await NotificationService.init();
    
    final MLService backgroundMLService = MLService();
    await backgroundMLService.loadModel();
    
    String text = message.body ?? "";
    String sender = message.address ?? "Unknown";

    final blockList = BlockListService();
    if (await blockList.isWhitelisted(sender)) {
      await NotificationService.showScanResult("Message from TRUSTED sender: $sender", "Safe", 100.0);
      return;
    }
    if (await blockList.isBlacklisted(sender)) {
      await NotificationService.showWarning("🚨 BLOCKED SENDER: $sender. Message ignored.");
      return;
    }

    final result = backgroundMLService.predict(text);
    
    // Save to Firebase for history
    await FirebaseFirestore.instance.collection('detections').add({
      "message": text,
      "label": result['label'],
      "confidence": result['confidence'],
      "timestamp": DateTime.now(),
      "sender": message.address,
      "type": "automatic"
    });

    // Determine Notification Content based on result
    if (result['label'] == "Fraud/Spam") {
      await NotificationService.showWarning(
        "Sender: ${message.address}\nResult: SCAM DETECTED\nConfidence: ${result['confidence'].toStringAsFixed(1)}%"
      );
    } else {
      // Show a "Safe" notification as well, matching Truecaller style which identifies callers
      await NotificationService.showScanResult(
        "Message from ${message.address} is SAFE.", 
        "Safe", 
        result['confidence']
      );
    }
  } catch (e) {
    print("Background Error: $e");
  }
}

class SmsService {
  final Telephony telephony = Telephony.instance;
  final MLService _mlService = MLService();

  Future<void> init() async {
    await _mlService.loadModel();
  }

  void startListening() {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        _handleIncomingSms(message);
      },
      onBackgroundMessage: backgrounSmsHandler,
    );
  }

  Future<void> _handleIncomingSms(SmsMessage message) async {
    if (!_mlService.isLoaded) await _mlService.loadModel();
    
    String text = message.body ?? "";
    String sender = message.address ?? "Unknown";
    final blockList = BlockListService();

    if (await blockList.isWhitelisted(sender)) {
      NotificationService.showScanResult("Message from TRUSTED sender: $sender", "Safe", 100.0);
      return;
    }
    if (await blockList.isBlacklisted(sender)) {
      NotificationService.showWarning("🚨 BLOCKED SENDER: $sender. Message ignored.");
      return;
    }

    final result = _mlService.predict(text);
    
    await FirebaseFirestore.instance.collection('detections').add({
      "message": text,
      "label": result['label'],
      "confidence": result['confidence'],
      "timestamp": DateTime.now(),
      "sender": sender,
      "type": "automatic"
    });

    if (result['label'] == "Fraud/Spam") {
      NotificationService.showWarning("🚨 SCAM DETECTED: [$sender]\n${text.substring(0, min(30, text.length))}...");
    } else {
      NotificationService.showScanResult(
        "Sender: $sender\nStatus: VERIFIED SAFE", 
        "Safe", 
        result['confidence']
      );
    }
  }

  Future<void> requestPermissions() async {
    await telephony.requestPhoneAndSmsPermissions;
  }
}
