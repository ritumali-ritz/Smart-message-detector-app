import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:intl/intl.dart';
import '../services/ml_service.dart';

class SmsDetailsScreen extends StatelessWidget {
  final SmsMessage message;
  final Map<String, dynamic>? scanResult;

  const SmsDetailsScreen({
    super.key, 
    required this.message, 
    this.scanResult,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFraud = scanResult?['label'] == "Fraud/Spam";
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(message.date ?? 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Message Thread", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: isFraud ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  child: Icon(
                    isFraud ? Icons.gpp_bad : Icons.person,
                    color: isFraud ? Colors.redAccent : Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.address ?? "Unknown",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // Message Bubble
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(
                  color: isFraud ? Colors.redAccent.withOpacity(0.3) : Colors.blueAccent.withOpacity(0.1),
                ),
              ),
              child: Text(
                message.body ?? "",
                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // AI Analysis Section
            const Text(
              "SHIELD ANALYSIS",
              style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 15),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isFraud ? Colors.red.withOpacity(0.05) : Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isFraud ? Colors.redAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isFraud ? Icons.warning_amber_rounded : Icons.verified_user,
                        color: isFraud ? Colors.redAccent : Colors.greenAccent,
                        size: 30,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFraud ? "Spam/Fraud Detected" : "Verified Safe",
                              style: TextStyle(
                                color: isFraud ? Colors.redAccent : Colors.greenAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "FraudShield certainty: ${scanResult?['confidence']?.toStringAsFixed(1) ?? '0'}%",
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isFraud) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(color: Colors.white10),
                    ),
                    const Text(
                      "Our AI detected suspicious patterns common in financial scams and promotional spam. We recommend not clicking any links or replying to this sender.",
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Logic to block or delete (placeholder)
                    },
                    icon: const Icon(Icons.block_flipped),
                    label: const Text("Block Sender"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Dismiss"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
