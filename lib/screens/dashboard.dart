import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../services/ml_service.dart';
import 'history.dart';
import 'sms_inbox.dart';
import 'feedback_screen.dart';
import 'block_list.dart';
import '../services/security_service.dart';
import '../services/block_list_service.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MLService _mlService = MLService();
  final SecurityService _securityService = SecurityService();
  final BlockListService _blockListService = BlockListService();
  String _statusMessage = "Shield is Active";
  bool _isDefaultSmsApp = false;
  bool _appLockEnabled = false;
  bool _isLocked = true;
  static const platform = MethodChannel('com.example.fraudmessagedetector/share');

  @override
  void initState() {
    super.initState();
    _mlService.loadModel();
    _checkAppLock();
    _checkDefaultSmsStatus();
    _checkSharedText();
  }

  Future<void> _checkAppLock() async {
    final enabled = await _securityService.isLockEnabled();
    setState(() => _appLockEnabled = enabled);
    
    if (enabled) {
      final authenticated = await _securityService.authenticate();
      if (authenticated) {
        setState(() => _isLocked = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication Failed. Please try again."))
        );
      }
    } else {
      setState(() => _isLocked = false);
    }
  }

  Future<void> _checkDefaultSmsStatus() async {
    try {
      final bool isDefault = await platform.invokeMethod('isDefaultSmsApp');
      setState(() {
        _isDefaultSmsApp = isDefault;
      });
    } catch (e) {
      print("Error checking default SMS status: $e");
    }
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

  void _showResultDialog(String text, Map<String, dynamic> result, {String sender = "Manual Scan"}) {
    bool isSpam = result['label'] == "Fraud/Spam";
    bool hasLink = result['hasSuspiciousLink'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(isSpam ? Icons.warning_amber_rounded : Icons.verified_user_outlined, 
                 color: isSpam ? Colors.redAccent : Colors.greenAccent, size: 40),
            const SizedBox(height: 10),
            Text(isSpam ? "🚨 FRAUD DETECTED" : "✅ SAFE MESSAGE", 
                style: TextStyle(color: isSpam ? Colors.redAccent : Colors.greenAccent, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Sender: $sender", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
              const SizedBox(height: 15),
              Text("Confidence: ${result['confidence'].toStringAsFixed(1)}%", style: const TextStyle(color: Colors.blueAccent)),
              
              if (hasLink) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.link_off, color: Colors.orangeAccent, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text("Suspicious Link Detected! Avoid clicking URLs in this message.", 
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (sender != "Manual Scan") ...[
            TextButton(
              onPressed: () async {
                await _blockListService.addToWhitelist(sender);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added $sender to Trusted list")));
              },
              child: const Text("Trust Sender", style: TextStyle(color: Colors.greenAccent)),
            ),
            TextButton(
              onPressed: () async {
                await _blockListService.addToBlacklist(sender);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Blocked $sender")));
              },
              child: const Text("Block Sender", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white))),
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
    if (_isLocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, color: Colors.blueAccent, size: 80),
              const SizedBox(height: 20),
              const Text("FraudShield is Locked", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _checkAppLock,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text("Unlock Now", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

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
              
              // NEW: Set Default SMS Button (Only shown if NOT default)
              if (!_isDefaultSmsApp)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final result = await platform.invokeMethod('setDefaultSmsApp');
                        if (result == true) {
                          _checkDefaultSmsStatus();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Action failed: $e"))
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: const Icon(Icons.settings_suggest),
                    label: const Text("Set FraudShield as Default SMS App"),
                  ),
                ),
              
              // NEW: Security & Filters Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.security, color: Colors.blueAccent, size: 20),
                              SizedBox(width: 10),
                              Text("App Lock Security", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Switch(
                            value: _appLockEnabled,
                            activeColor: Colors.blueAccent,
                            onChanged: (val) async {
                              if (val) {
                                bool canAuth = await _securityService.isBiometricAvailable();
                                if (canAuth) {
                                  await _securityService.setLockEnabled(true);
                                  setState(() => _appLockEnabled = true);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Biometrics not available on this device"))
                                  );
                                }
                              } else {
                                await _securityService.setLockEnabled(false);
                                setState(() => _appLockEnabled = false);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
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
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FeedbackScreen())),
                icon: const Icon(Icons.rate_review_outlined, color: Colors.blueAccent),
                label: const Text("Help us improve: Rate FraudShield", style: TextStyle(color: Colors.blueAccent)),
              ),
              const SizedBox(height: 30),
              
              // Remove Default App Option at the very bottom
              if (_isDefaultSmsApp)
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await platform.invokeMethod('openDefaultAppsSettings');
                    } catch (e) {
                      print("Error opening settings: $e");
                    }
                  },
                  icon: const Icon(Icons.no_cell, color: Colors.redAccent, size: 16),
                  label: const Text("Remove FraudShield as Default", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
