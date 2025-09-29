import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _topicController = TextEditingController();
  String _selectedType = 'Short Notes';
  String _result = '';
  bool _loading = false;

  Future<void> _handleGenerate() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() => _loading = true);
    final notes = await AIService.generateNotes(topic, _selectedType);
    setState(() {
      _result = notes;
      _loading = false;
    });
  }

  Future<void> _saveNote() async {
    if (_result.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> savedNotes = prefs.getStringList('saved_notes') ?? [];

    // Create a note with metadata
    final noteData = {
      'topic': _topicController.text.trim(),
      'type': _selectedType,
      'content': _result,
      'date': DateTime.now().toIso8601String(),
    };

    savedNotes.add(json.encode(noteData));
    await prefs.setStringList('saved_notes', savedNotes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved successfully!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Color definitions
    final primaryColor = isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple;
    final cardColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final inputFillColor = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;
    final iconColor = isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple;
    final buttonColor = isDarkMode ? Colors.deepPurpleAccent[400]! : Colors.deepPurple;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "AI Notes Generator",
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.deepPurple,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.deepPurple,
        ),
        actions: [
          if (_result.isNotEmpty)
            IconButton(
              icon: Icon(Icons.save, color: iconColor),
              onPressed: _saveNote,
            ),
        ],
      ),
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input Card
            Card(
              elevation: 2,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _topicController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Enter a topic',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.topic, color: iconColor),
                        filled: true,
                        fillColor: inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.format_list_bulleted, color: iconColor),
                        const SizedBox(width: 10),
                        Text(
                          "Select Notes Type: ",
                          style: TextStyle(color: textColor),
                        ),
                        const SizedBox(width: 10),
                        Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: cardColor,
                          ),
                          child: DropdownButton<String>(
                            value: _selectedType,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: cardColor,
                            style: TextStyle(color: textColor),
                            icon: Icon(Icons.arrow_drop_down, color: iconColor),
                            underline: Container(),
                            items: ['Short Notes', 'Detailed Notes']
                                .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedType = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleGenerate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: _loading
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome,
                                color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              "Generate Notes",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Results Section
            if (_result.isNotEmpty)
              Card(
                elevation: 2,
                color: isDarkMode ? Colors.grey[850] : Colors.deepPurple[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notes, color: primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                "Generated Notes",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.save, color: primaryColor),
                            onPressed: _saveNote,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _result,
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (!_loading)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.note_add_outlined,
                      size: 60,
                      color: textColor.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Enter a topic to generate notes",
                      style: TextStyle(
                        fontSize: 18,
                        color: textColor.withOpacity(0.5),
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

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }
}