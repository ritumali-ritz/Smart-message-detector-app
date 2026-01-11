import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

class MLService {
  Map<String, dynamic>? _modelData;
  bool isLoaded = false;

  Future<void> loadModel() async {
    try {
      String jsonString = await rootBundle.loadString('assets/model/model_weights.json');
      _modelData = jsonDecode(jsonString);
      isLoaded = true;
    } catch (e) {
      print("Error loading offline model: $e");
    }
  }

  String _preprocess(String text) {
    return text.toLowerCase()
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't')
        .replaceAll('8', 'b');
  }

  Map<String, dynamic> predict(String text) {
    if (!isLoaded) return {"label": "Scanning...", "confidence": 0.0};

    String cleanText = _preprocess(text);
    List<String> words = cleanText.split(RegExp(r'\W+'));
    
    Map<String, int> vocab = Map<String, int>.from(_modelData!['vocabulary']);
    List<double> priors = List<double>.from(_modelData!['class_log_prior']);
    List<List<double>> featureProbs = List<List<double>>.from(
        _modelData!['feature_log_prob'].map((list) => List<double>.from(list)));

    List<double> scores = List.from(priors);

    bool foundSpamKeywords = false;
    for (String word in words) {
      if (vocab.containsKey(word)) { 
        int index = vocab[word]!;
        foundSpamKeywords = true;
        for (int i = 0; i < scores.length; i++) {
          scores[i] += featureProbs[i][index];
        }
      }
    }

    // 3. Advanced Phishing & Spam Link Detector
    bool hasLink = text.contains(RegExp(r'http[s]?://|www\.|bit\.ly|tinyurl|wa\.me|t\.me'));
    
    // Specific Keyword Boosting for common Indian Spam
    List<String> dangerKeywords = ['recharge', 'rummy', 'betting', 'bonus', 'claim', 'won', 'lottery', 'offer', 'loan', 'kyc', 'pan', 'blocked', 'suspended', 'electricity', 'disconnect', 'exclusive', 'cashback', 'gift', 'win', 'earn'];
    
    double boost = 0.0;
    bool keywordFound = false;
    for (String kw in dangerKeywords) {
      if (cleanText.contains(kw)) {
        boost += 0.2;
        keywordFound = true;
      }
    }

    double maxLog = scores.reduce(max);
    List<double> expScores = scores.map((s) => exp(s - maxLog)).toList();
    double sumExp = expScores.reduce((a, b) => a + b);
    List<double> probabilities = expScores.map((s) => s / sumExp).toList();

    // If keywords found, we treat it with much higher suspicion by default
    double fraudProb = probabilities[1];
    if (keywordFound) {
      fraudProb = max(fraudProb, 0.5); // Baseline 50% if spam words present
    }
    
    // BOOST logic
    if (hasLink) fraudProb += 0.3;
    fraudProb += boost;
    
    if (fraudProb > 0.99) fraudProb = 0.99;
    if (fraudProb < 0.01) fraudProb = 0.01;

    // Even more aggressive threshold
    int bestClassIndex = fraudProb > 0.35 ? 1 : 0; 
    String label = bestClassIndex == 1 ? "Fraud/Spam" : "Safe";

    return {
      "label": label,
      "confidence": (bestClassIndex == 1 ? fraudProb : (1 - fraudProb)) * 100,
      "hasSuspiciousLink": hasLink,
      "boostScore": boost,
    };
  }
}
