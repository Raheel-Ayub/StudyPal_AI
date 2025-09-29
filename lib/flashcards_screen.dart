import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({Key? key}) : super(key: key);

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  List<Map<String, String>> _flashcards = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  final TextEditingController _frontController = TextEditingController();
  final TextEditingController _backController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    final prefs = await SharedPreferences.getInstance();
    final cards = prefs.getStringList('flashcards') ?? [];
    setState(() {
      _flashcards = cards.map((item) =>
      Map<String, String>.from(json.decode(item))
      ).toList();
    });
  }

  Future<void> _saveFlashcard() async {
    if (_frontController.text.isEmpty || _backController.text.isEmpty) return;

    final newCard = {
      'front': _frontController.text,
      'back': _backController.text,
    };

    final prefs = await SharedPreferences.getInstance();
    final updatedCards = [..._flashcards, newCard];
    await prefs.setStringList('flashcards',
        updatedCards.map((card) => json.encode(card)).toList()
    );

    setState(() {
      _flashcards = updatedCards;
      _frontController.clear();
      _backController.clear();
    });
  }

  Future<void> _deleteFlashcard(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _flashcards.removeAt(index);
      if (_currentIndex >= _flashcards.length) {
        _currentIndex = _flashcards.length - 1;
      }
    });
    await prefs.setStringList('flashcards',
        _flashcards.map((card) => json.encode(card)).toList()
    );
  }

  void _showAddFlashcardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Flashcard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _frontController,
              decoration: const InputDecoration(labelText: 'Front (Question)'),
            ),
            TextField(
              controller: _backController,
              decoration: const InputDecoration(labelText: 'Back (Answer)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveFlashcard();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddFlashcardDialog,
          ),
        ],
      ),
      body: _flashcards.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No flashcards yet'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showAddFlashcardDialog,
              child: const Text('Create First Flashcard'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: Card(
                margin: const EdgeInsets.all(24),
                elevation: 8,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _showAnswer
                          ? _flashcards[_currentIndex]['back']!
                          : _flashcards[_currentIndex]['front']!,
                      style: const TextStyle(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentIndex > 0
                      ? () {
                    setState(() {
                      _currentIndex--;
                      _showAnswer = false;
                    });
                  }
                      : null,
                ),
                Text(
                  '${_currentIndex + 1}/${_flashcards.length}',
                  style: const TextStyle(fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentIndex < _flashcards.length - 1
                      ? () {
                    setState(() {
                      _currentIndex++;
                      _showAnswer = false;
                    });
                  }
                      : null,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteFlashcard(_currentIndex),
          ),
        ],
      ),
    );
  }
}