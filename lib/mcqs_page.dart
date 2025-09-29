import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'mcqs_history_screen.dart';

class MCQsPage extends StatefulWidget {
  @override
  _MCQsPageState createState() => _MCQsPageState();
}

class _MCQsPageState extends State<MCQsPage> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: '10');
  bool _isLoading = false;
  List<String> _mcqs = [];
  String _currentTopic = '';

  Future<void> generateMCQs(String topic, int count) async {
    setState(() {
      _isLoading = true;
      _mcqs.clear();
      _currentTopic = topic;
    });

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer api key',
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": [
            {
              "role": "user",
              "content":
              "Generate $count multiple choice questions with 4 options and mark the correct option with [correct] on the topic: $topic"
            }
          ],
          "temperature": 0.7
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String content = data['choices'][0]['message']['content'];
        final mcqsList = content.split('\n').where((line) => line.trim().isNotEmpty).toList();

        setState(() {
          _mcqs = mcqsList;
        });

        // Save to history
        await _saveToHistory(topic, mcqsList);
      } else {
        throw Exception('Failed to load MCQs');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating MCQs: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveToHistory(String topic, List<String> mcqs) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('mcqs_history') ?? [];

    final mcqSet = {
      'topic': topic,
      'questions': mcqs,
      'date': DateTime.now().toIso8601String(),
    };

    history.add(json.encode(mcqSet));
    await prefs.setStringList('mcqs_history', history);
  }

  @override
  void dispose() {
    _topicController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.amber : Colors.deepPurple;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final inputFillColor = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;
    final correctAnswerColor = isDarkMode ? Colors.greenAccent : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI MCQs Generator',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.deepPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.deepPurple,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _topicController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Enter Topic',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        filled: true,
                        fillColor: inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.search, color: primaryColor),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _countController,
                            style: TextStyle(color: textColor),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Number of MCQs',
                              labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                              filled: true,
                              fillColor: inputFillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.numbers, color: primaryColor),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 150,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                              final topic = _topicController.text.trim();
                              final count = int.tryParse(_countController.text) ?? 10;
                              if (topic.isNotEmpty) {
                                generateMCQs(topic, count);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                                : const Text(
                              'Generate',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Results Section
            Expanded(
              child: _isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                ),
              )
                  : _mcqs.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.quiz,
                      size: 60,
                      color: textColor.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter a topic to generate MCQs',
                      style: TextStyle(
                        fontSize: 18,
                        color: textColor.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              )
                  : Card(
                elevation: 2,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.builder(
                    itemCount: _mcqs.length,
                    itemBuilder: (context, index) {
                      final mcqLine = _mcqs[index].trim();
                      final isQuestion = RegExp(r'^\d+[\).]').hasMatch(mcqLine);
                      final isCorrect = mcqLine.contains('[correct]');

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isQuestion)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 12.0,
                                  bottom: 6,
                                ),
                                child: Text(
                                  mcqLine,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: isCorrect
                                          ? correctAnswerColor
                                          : textColor.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        mcqLine.replaceAll(
                                            '[correct]', ''),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isCorrect
                                              ? correctAnswerColor
                                              : textColor,
                                          fontWeight: isCorrect
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (index == _mcqs.length - 1 ||
                                RegExp(r'^\d+[\).]')
                                    .hasMatch(_mcqs[index + 1]))
                              Divider(
                                thickness: 1.0,
                                height: 30,
                                color: isDarkMode
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
