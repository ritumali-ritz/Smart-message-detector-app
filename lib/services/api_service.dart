import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace with your computer's IP for real device testing
  static const String baseUrl = "http://10.0.2.2:5000";

  Future<Map<String, dynamic>> predictMessage(String message, String userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/predict"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "message": message,
          "user_id": userId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"error": "Server error: ${response.statusCode}", "label": "Error", "confidence": 0.0};
      }
    } catch (e) {
      return {"error": "Connection failed: $e", "label": "Error", "confidence": 0.0};
    }
  }
}
