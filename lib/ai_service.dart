import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const apiKey = "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"; // replace with actual key
  static const apiUrl = "https://openrouter.ai/api/v1/chat/completions";

  static Future<String> generateNotes(String topic, String type) async {
    final prompt = "Generate $type on the topic: $topic";

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey"
      },
      body: jsonEncode({
        "model": "openai/gpt-3.5-turbo",
        "messages": [
          {"role": "user", "content": prompt}
        ]
      }),
    );

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }
}
