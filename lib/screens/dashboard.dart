import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../services/ml_service.dart';
import 'history.dart';
import 'sms_inbox.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MLService _mlService = MLService();
  String _statusMessage = "Shield is Active";
  static const platform = MethodChannel('com.example.fraudmessagedetector/share');

  @override
  void initState() {
    super.initState();
    _mlService.loadModel();
    _checkSharedText();
  }

  Future<void> _checkSharedText() async {
    try {
      final String? sharedText = await platform.invokeMethod('getSharedText');
      if (sharedText != null && sharedText.isNotEmpty) {
        // Delay slightly ensuring UI is built
        Future.delayed(const Duration(milliseconds: 500), () {
          _triggerScan(sharedText);
        });
      }
    } catch (e) {
      print("Error getting shared text: $e");
    }
  }

  void _triggerScan(String text) async {
      setState(() => _statusMessage = "Analyzing Shared Text...");
      final result = _mlService.predict(text);
      
      // Log manual scan to History too!
      await FirebaseFirestore.instance.collection('detections').add({
        "message": text,
        "label": result['label'],
        "confidence": result['confidence'],
        "timestamp": DateTime.now(),
      });

      setState(() {
        _statusMessage = "Last result: ${result['label']} (${(result['confidence'] ?? 0).toStringAsFixed(1)}%)";
      });
      
      // Also show the dialog so they see the full result
      _showResultDialog(text, result);
  }

  void _showResultDialog(String text, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(result['label'] == "Fraud/Spam" ? "🚨 FRUAD DETECTED" : "✅ Message is Safe", 
          style: TextStyle(color: result['label'] == "Fraud/Spam" ? Colors.redAccent : Colors.greenAccent)),
        content: Text("Analysis for:\n$text\n\nConfidence: ${result['confidence']}%", style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  void _manualTest() async {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Manual Scan", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller, 
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Paste message here...",
            hintStyle: TextStyle(color: Colors.white38),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _statusMessage = "Analyzing...");
              final result = _mlService.predict(controller.text);
              
              // Log manual scan to History too!
              await FirebaseFirestore.instance.collection('detections').add({
                "message": controller.text,
                "label": result['label'],
                "confidence": result['confidence'],
                "timestamp": DateTime.now(),
              });

              setState(() {
                _statusMessage = "Last result: ${result['label']} (${(result['confidence'] ?? 0).toStringAsFixed(1)}%)";
              });
            },
            child: const Text("Scan"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Security Icon with Pulse effect
              Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.1),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: const Icon(Icons.security, size: 80, color: Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "FraudShield Active",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 16, color: Colors.greenAccent),
              ),
              const SizedBox(height: 15),
              
              // NEW: Set Default SMS Buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      print("Requesting Default SMS App change...");
                      try {
                        final result = await platform.invokeMethod('setDefaultSmsApp');
                        print("Result from Native: $result");
                        if (result == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Requesting system dialog..."))
                          );
                        } else if (result == false) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("FraudShield is already your Default SMS App!"))
                          );
                        }
                      } catch (e) {
                        print("Error setting default SMS app: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Action failed: $e"))
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.settings_suggest, size: 18),
                    label: const Text("Set as Default SMS App", style: TextStyle(fontSize: 12)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await platform.invokeMethod('openDefaultAppsSettings');
                      } catch (e) {
                        print("Error opening settings: $e");
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.no_cell, size: 18),
                    label: const Text("Remove as Default", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              
              const SizedBox(height: 50),
              
              // Latest Activity Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Latest Activity", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('detections')
                            .orderBy('timestamp', descending: true)
                            .limit(1)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Text("No scans yet", style: TextStyle(color: Colors.white30));
                          }
                          var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                          bool isFraud = data['label'] == "Fraud/Spam";
                          return Row(
                            children: [
                              Icon(isFraud ? Icons.warning : Icons.check_circle, 
                                   color: isFraud ? Colors.redAccent : Colors.greenAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  data['message'] ?? "",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Daily Stats Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Text("Scanned Today", style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 5),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('detections')
                                  .where('timestamp', isGreaterThan: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const Text("-", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold));
                                return Text(
                                  "${snapshot.data!.docs.length}",
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Text("Threats Blocked", style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 5),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('detections')
                                  .where('label', isEqualTo: 'Fraud/Spam')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const Text("-", style: TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold));
                                return Text(
                                  "${snapshot.data!.docs.length}",
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _manualTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(250, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                icon: const Icon(Icons.search),
                label: const Text("Scan Text Manually", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SmsInboxScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(250, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                icon: const Icon(Icons.message),
                label: const Text("Open Messages", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
                icon: const Icon(Icons.history, color: Colors.white70),
                label: const Text("View All Scan History", style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
