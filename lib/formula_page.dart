import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FormulaScreen extends StatefulWidget {
  @override
  _FormulaScreenState createState() => _FormulaScreenState();
}

class _FormulaScreenState extends State<FormulaScreen> {
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _chapterController = TextEditingController();
  String _result = '';
  bool _isLoading = false;
  String _selectedOption = 'Both'; // 'Both', 'Formulas', 'Questions'

  Future<void> generateContent() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    String prompt;
    if (_selectedOption == 'Both') {
      prompt = "Give me all formulas and important questions from ${_subjectController.text} of class ${_classController.text} for chapter ${_chapterController.text}. First give formulas under heading \uD83D\uDCDA Formulas and then important questions under heading \u2753 Important Questions.";
    } else if (_selectedOption == 'Formulas') {
      prompt = "Give me all formulas from ${_subjectController.text} of class ${_classController.text} for chapter ${_chapterController.text}. Present them under heading \uD83D\uDCDA Formulas.";
    } else {
      prompt = "Give me important questions from ${_subjectController.text} of class ${_classController.text} for chapter ${_chapterController.text}. Present them under heading \u2753 Important Questions.";
    }

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer api key',
        },
        body: jsonEncode({
          "model": "openai/gpt-3.5-turbo",
          "messages": [
            {"role": "user", "content": prompt}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _result = data['choices'][0]['message']['content'];
        });
      } else {
        setState(() {
          _result = 'Error: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.greenAccent : Colors.deepPurple;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final inputFillColor = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Formulas & Questions",
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
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _classController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Class (e.g., 10th)',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        filled: true,
                        fillColor: inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.school, color: primaryColor),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _subjectController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Book/Subject',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        filled: true,
                        fillColor: inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.menu_book, color: primaryColor),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _chapterController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Chapter Name/Number',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        filled: true,
                        fillColor: inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.list, color: primaryColor),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.filter_list, color: primaryColor),
                        SizedBox(width: 10),
                        Text(
                          "Content Type: ",
                          style: TextStyle(color: textColor),
                        ),
                        SizedBox(width: 10),
                        DropdownButton<String>(
                          value: _selectedOption,
                          dropdownColor: cardColor,
                          style: TextStyle(color: textColor),
                          icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                          items: ['Both', 'Formulas', 'Questions']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedOption = value!;
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: generateContent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                            : Text(
                          "Generate Content",
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
              ),
            ),
            SizedBox(height: 20),
            // Results Section
            Expanded(
              child: _isLoading
                  ? Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
                  : _result.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.science,
                      size: 60,
                      color: textColor.withOpacity(0.3),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Enter details to generate content",
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
                  child: SingleChildScrollView(
                    child: Text(
                      _result,
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
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
