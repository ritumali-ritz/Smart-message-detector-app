import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../services/ml_service.dart';
import 'sms_details.dart';

class SmsInboxScreen extends StatefulWidget {
  const SmsInboxScreen({super.key});

  @override
  State<SmsInboxScreen> createState() => _SmsInboxScreenState();
}

class _SmsInboxScreenState extends State<SmsInboxScreen> {
  final Telephony telephony = Telephony.instance;
  List<SmsMessage> messages = [];
  final MLService _mlService = MLService();
  Map<String, Map<String, dynamic>> _scanResults = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    await _mlService.loadModel();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // Get more messages, up to 200
      final List<SmsMessage> msgs = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.ID],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
      
      if (mounted) {
        setState(() {
          messages = msgs;
          _isLoading = false;
        });
        
        // Auto-scan the first 20 for immediate feedback
        _autoScanVisible();
      }
    } catch (e) {
      print("Error loading SMS: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _autoScanVisible() {
    // Scan the most recent messages automatically
    for (var i = 0; i < min(20, messages.length); i++) {
      _scanMessage(messages[i]);
    }
  }

  Future<void> _scanMessage(SmsMessage message) async {
    final result = _mlService.predict(message.body ?? "");
    if (mounted) {
      setState(() {
        _scanResults[message.id.toString()] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("SMS Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.message_outlined, size: 60, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text("No messages found or permission denied", 
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMessages,
                  child: ListView.builder(
                    itemCount: messages.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final scanResult = _scanResults[msg.id.toString()];
                      final isFraud = scanResult?['label'] == "Fraud/Spam";
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isFraud ? Colors.redAccent.withOpacity(0.3) : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isFraud ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFraud ? Icons.gpp_bad : Icons.person_outline,
                              color: isFraud ? Colors.redAccent : Colors.blueAccent,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  msg.address ?? "Unknown",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                DateFormat('hh:mm a').format(
                                  DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0),
                                ),
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                msg.body ?? "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              if (scanResult != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isFraud ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isFraud ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                                            size: 12,
                                            color: isFraud ? Colors.redAccent : Colors.greenAccent,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isFraud ? "SPAM DETECTED" : "SAFE",
                                            style: TextStyle(
                                              color: isFraud ? Colors.redAccent : Colors.greenAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${scanResult['confidence'].toStringAsFixed(0)}% Certainty",
                                      style: const TextStyle(color: Colors.white24, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SmsDetailsScreen(
                                  message: msg,
                                  scanResult: scanResult,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
