import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class QuizPage extends StatefulWidget {
  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: '5');
  bool _isLoading = false;
  List<Question> _questions = [];
  int _score = 0;
  bool _quizSubmitted = false;

  Future<void> generateQuiz(String topic, int count) async {
    setState(() {
      _isLoading = true;
      _questions.clear();
      _quizSubmitted = false;
      _score = 0;
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
              "Generate $count multiple choice questions with 4 options (A, B, C, D) and mark the correct option with [correct] on the topic: $topic. Format strictly:\nQ1. Question text?\nA. Option text\nB. Option text\nC. Option text [correct]\nD. Option text\n\nOnly return plain text in this format without any markdown like bolding or italics."
            }
          ],
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String content = data['choices'][0]['message']['content'];
        final parsedQuestions = _parseQuestions(content);

        if (parsedQuestions.isEmpty) {
          throw Exception("No questions could be parsed from the response. Please try a different topic.");
        }

        setState(() {
          _questions = parsedQuestions;
        });
      } else {
        throw Exception('Failed to load questions: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating quiz: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Robust parser:
  /// - Finds lines starting with Q\d+.
  /// - For each question, collects exactly the lines that start with A/B/C/D.
  /// - Detects [correct] on the option line (case-insensitive).
  /// - Also supports "Answer: C" style lines if present.
  List<Question> _parseQuestions(String content) {
    final List<String> lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final qRe = RegExp(r'^Q\s*\d+[\.\:\)]\s*(.*)$', caseSensitive: false);
    final optRe = RegExp(r'^([A-D])[\.\:\)\-]\s*(.*)$', caseSensitive: false);
    final correctTag = RegExp(r'\[\s*correct\s*\]', caseSensitive: false);
    final answerLineRe = RegExp(r'^(?:answer|correct\s*answer)\s*[:\-]\s*([A-D])$', caseSensitive: false);

    List<Question> result = [];
    String? currentQuestion;
    List<String> optionTexts = [];
    int correctIndex = -1;

    void flushCurrent() {
      if (currentQuestion != null && optionTexts.length == 4) {
        // If still no [correct] found, leave fallback to -1; the factory will handle it.
        result.add(Question.fromParsed(currentQuestion!, optionTexts, correctIndex));
      }
      currentQuestion = null;
      optionTexts = [];
      correctIndex = -1;
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // If we see a new question, flush previous.
      final qMatch = qRe.firstMatch(line);
      if (qMatch != null) {
        flushCurrent();
        currentQuestion = qMatch.group(1)!.trim();
        continue;
      }

      if (currentQuestion == null) {
        // ignore lines until first question appears
        continue;
      }

      // Options A-D
      final oMatch = optRe.firstMatch(line);
      if (oMatch != null) {
        if (optionTexts.length < 4) {
          String optText = oMatch.group(2)!.trim();

          // detect [correct] right on the option line
          if (correctTag.hasMatch(optText)) {
            correctIndex = optionTexts.length;
            optText = optText.replaceAll(correctTag, '').trim();
          }
          optionTexts.add(optText);
        }
        continue;
      }

      // If we already have 4 options, we can look for an "Answer: C" style hint
      // some models append this line after the options.
      if (optionTexts.length == 4 && correctIndex == -1) {
        final aMatch = answerLineRe.firstMatch(line);
        if (aMatch != null) {
          final letter = aMatch.group(1)!.toUpperCase();
          correctIndex = letter.codeUnitAt(0) - 65; // A->0, B->1...
        }
      }
    }

    // Flush the last question if any
    flushCurrent();

    return result;
  }

  Future<void> _saveQuizResult(String topic, int score, int total) async {
    final prefs = await SharedPreferences.getInstance();
    final resultsJson = prefs.getString('quiz_results');
    List<Map<String, dynamic>> results = [];

    if (resultsJson != null) {
      results = List<Map<String, dynamic>>.from(jsonDecode(resultsJson));
    }

    results.add({
      'topic': topic,
      'score': score,
      'total': total,
      'date': DateTime.now().toIso8601String(),
    });

    await prefs.setString('quiz_results', jsonEncode(results));
  }

  void submitQuiz() async {
    if (_questions.any((q) => q.selectedOption == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please answer all questions"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final score = _questions.where((q) => q.selectedOption == q.correctOption).length;
    final topic = _topicController.text.trim();

    await _saveQuizResult(topic, score, _questions.length);

    setState(() {
      _score = score;
      _quizSubmitted = true;
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.blueAccent : Colors.deepPurple;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final inputFillColor = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;
    final correctColor = isDarkMode ? Colors.greenAccent[400]! : Colors.green;
    final incorrectColor = isDarkMode ? Colors.red[400]! : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "AI Quiz Generator",
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
            Card(
              elevation: 2,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _topicController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Quiz Topic",
                        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        filled: true,
                        fillColor: inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.quiz, color: primaryColor),
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
                              labelText: "Number of Questions",
                              labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                              filled: true,
                              fillColor: inputFillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.format_list_numbered, color: primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                            final topic = _topicController.text.trim();
                            final count = int.tryParse(_countController.text) ?? 5;
                            if (topic.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enter a topic")),
                              );
                              return;
                            }
                            generateQuiz(topic, count);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                              : const Text("Generate", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : _questions.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.quiz_outlined, size: 60, color: textColor.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      "Enter a topic to generate a quiz",
                      style: TextStyle(fontSize: 18, color: textColor.withOpacity(0.5)),
                    ),
                  ],
                ),
              )
                  : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        final q = _questions[index];
                        return Card(
                          elevation: 2,
                          color: cardColor,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: _quizSubmitted
                                ? BorderSide(
                              color: q.selectedOption == q.correctOption
                                  ? correctColor
                                  : incorrectColor,
                              width: 1.5,
                            )
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  q.questionText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...q.options.asMap().entries.map((entry) {
                                  final optIndex = entry.key;
                                  final optText = entry.value;
                                  final isCorrectAnswer = optIndex == q.correctOption;
                                  final isSelected = optIndex == q.selectedOption;

                                  Color optionTextColor = textColor;
                                  Widget? trailingIcon;

                                  if (_quizSubmitted) {
                                    if (isCorrectAnswer) {
                                      optionTextColor = correctColor;
                                      trailingIcon = Icon(Icons.check_circle, color: correctColor);
                                    } else if (isSelected && !isCorrectAnswer) {
                                      optionTextColor = incorrectColor;
                                      trailingIcon = Icon(Icons.cancel, color: incorrectColor);
                                    }
                                  }

                                  return RadioListTile<int>(
                                    title: Text(optText, style: TextStyle(color: optionTextColor)),
                                    value: optIndex,
                                    groupValue: q.selectedOption,
                                    onChanged: !_quizSubmitted
                                        ? (value) => setState(() => q.selectedOption = value)
                                        : null,
                                    activeColor: primaryColor,
                                    secondary: trailingIcon,
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_questions.isNotEmpty && !_quizSubmitted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitQuiz,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Submit Quiz",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  if (_quizSubmitted)
                    Card(
                      color: cardColor,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text("Quiz Results",
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
                            const SizedBox(height: 16),
                            Text(
                              "You Scored: $_score / ${_questions.length}",
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${(_score / _questions.length * 100).toStringAsFixed(1)}%",
                              style: TextStyle(fontSize: 20, color: textColor.withOpacity(0.8)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: Icon(Icons.refresh, color: Colors.white),
                              label: Text("Try Another Quiz", style: TextStyle(color: Colors.white)),
                              onPressed: () {
                                setState(() {
                                  _questions = [];
                                  _quizSubmitted = false;
                                  _topicController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Question {
  final String questionText;
  final List<String> options; // "A. ...", "B. ...", etc. (display text)
  final int correctOption;    // 0..3
  int? selectedOption;

  Question({
    required this.questionText,
    required this.options,
    required this.correctOption,
    this.selectedOption,
  });

  /// Build from already-parsed question text and 4 option texts (without letters).
  /// `correctIndex` can be -1 (unknown) and will default to 0.
  factory Question.fromParsed(String qText, List<String> optionsNoLetters, int correctIndex) {
    // clamp and fallback
    int idx = (correctIndex >= 0 && correctIndex < 4) ? correctIndex : 0;

    final display = List<String>.generate(
      4,
          (i) => '${String.fromCharCode(65 + i)}. ${optionsNoLetters[i].trim()}',
    );

    return Question(
      questionText: qText.trim(),
      options: display,
      correctOption: idx,
    );
  }

  /// Kept for compatibility (unused in new parser). Safe, tolerant version.
  factory Question.fromRaw(String question, List<String> rawOptions) {
    int correctIndex = -1;
    List<String> cleaned = [];

    final correctTag = RegExp(r'\[\s*correct\s*\]', caseSensitive: false);

    for (int i = 0; i < rawOptions.length && i < 4; i++) {
      String option = rawOptions[i].trim();

      if (option.toLowerCase().contains('[correct]')) {
        correctIndex = i;
      }

      // remove any leading label like "A.", "A)", "A -"
      option = option.replaceFirst(RegExp(r'^[A-D][\.\:\)\-]\s*', caseSensitive: false), '');
      option = option.replaceAll(correctTag, '').trim();

      cleaned.add(option);
    }

    // pad if fewer than 4 (defensive)
    while (cleaned.length < 4) {
      cleaned.add('Option ${cleaned.length + 1}');
    }

    return Question.fromParsed(
      question.replaceFirst(RegExp(r'^Q\s*\d+[\.\:\)]\s*', caseSensitive: false), '').trim(),
      cleaned,
      correctIndex,
    );
  }
}
