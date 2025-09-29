import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'home_screen.dart';
import 'image_to_pdf_screen.dart';
import 'saved_notes_screen.dart';
import 'mcqs_history_screen.dart';
import 'flashcards_screen.dart';
import 'settings_screen.dart';

class QuizResultScreen extends StatefulWidget {
  @override
  _QuizResultScreenState createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  List<Map<String, dynamic>> _quizResults = [];
  bool _isLoading = true;
  bool _isDarkMode = false;
  int _selectedDrawerIndex = 3; // Quiz Results is at index 3 in drawer items

  final List<Map<String, dynamic>> _drawerItems = [
    {'title': 'Home', 'icon': Icons.home_filled, 'screen': HomeScreen()},
    {'title': 'Saved Notes', 'icon': Icons.bookmark_added_rounded, 'screen': SavedNotesScreen()},
    {'title': 'MCQs History', 'icon': Icons.history_edu_rounded, 'screen': MCQsHistoryScreen()},
    {'title': 'Quiz Results', 'icon': Icons.analytics_rounded, 'screen': QuizResultScreen()},
    {'title': 'Flashcards', 'icon': Icons.flash_on_rounded, 'screen': FlashcardsScreen()},
    {'title': 'Image to PDF', 'icon': Icons.picture_as_pdf_rounded, 'screen': ImageToPdfScreen()},
    {'title': 'Settings', 'icon': Icons.settings_rounded, 'screen': SettingsScreen()},
  ];

  @override
  void initState() {
    super.initState();
    _loadQuizResults();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = value;
    });
    await prefs.setBool('isDarkMode', value);
  }

  Future<void> _loadQuizResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resultsJson = prefs.getString('quiz_results');

      if (resultsJson != null) {
        final decodedResults = jsonDecode(resultsJson) as List;
        setState(() {
          _quizResults = decodedResults.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error loading quiz results: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearResults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History"),
        content: const Text("Are you sure you want to delete all quiz results?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('quiz_results');
      setState(() {
        _quizResults = [];
      });
    }
  }

  void _navigateToScreen(Widget screen, int index) {
    setState(() => _selectedDrawerIndex = index);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Theme(
          data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
          child: screen,
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? [Colors.deepPurple.shade800, Colors.purple.shade800]
                    : [Colors.deepPurple, Colors.purple],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.school_rounded,
                      size: 40,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'StudyPal AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Learning Companion',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ..._drawerItems.asMap().entries.map((entry) {
            int index = entry.key;
            var item = entry.value;
            bool isSelected = _selectedDrawerIndex == index;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (_isDarkMode
                    ? Colors.deepPurple.shade800.withOpacity(0.5)
                    : Colors.deepPurple.withOpacity(0.1))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  item['icon'],
                  color: isSelected
                      ? Colors.deepPurple
                      : _isDarkMode
                      ? Colors.white70
                      : Colors.grey[700],
                ),
                title: Text(
                  item['title'],
                  style: TextStyle(
                    color: isSelected
                        ? _isDarkMode
                        ? Colors.white
                        : Colors.deepPurple
                        : _isDarkMode
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: _isDarkMode ? Colors.white70 : Colors.deepPurple,
                )
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (item['screen'] != null) {
                    _navigateToScreen(item['screen'], index);
                  } else {
                    setState(() => _selectedDrawerIndex = index);
                  }
                },
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          Divider(
            color: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
            thickness: 1,
            indent: 16,
            endIndent: 16,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: _isDarkMode ? Colors.red[300] : Colors.red,
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: _isDarkMode ? Colors.red[300] : Colors.red,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                // Add logout functionality here
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Developed by',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Muhammad Raheel Ayub',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '© 2025 All Rights Reserved',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.blueAccent : Colors.deepPurple;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final correctColor = isDarkMode ? Colors.greenAccent[400]! : Colors.green;
    final incorrectColor = isDarkMode ? Colors.red[400]! : Colors.red;

    return Theme(
      data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        drawer: _buildDrawer(),
        appBar: AppBar(
          title: Text(
            "Quiz History",
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(
            color: _isDarkMode ? Colors.white : Colors.deepPurple,
          ),
          actions: [
            if (_quizResults.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _clearResults,
                tooltip: "Clear History",
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _quizResults.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_outlined,
                size: 60,
                color: textColor.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                "No quiz history yet",
                style: TextStyle(
                  fontSize: 18,
                  color: textColor.withOpacity(0.5),
                ),
              ),
            ],
          ),
        )
            : ListView.builder(
          itemCount: _quizResults.length,
          itemBuilder: (context, index) {
            final result = _quizResults.reversed.toList()[index];
            final date = DateTime.parse(result['date']);
            final formattedDate = DateFormat('MMM dd, yyyy - HH:mm').format(date);
            final percentage = (result['score'] / result['total'] * 100).toStringAsFixed(1);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            result['topic'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          "Score: ",
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        Text(
                          "${result['score']}/${result['total']}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: result['score'] == result['total']
                                ? correctColor
                                : result['score'] > result['total'] / 2
                                ? Colors.orange
                                : incorrectColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "$percentage%",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: result['score'] / result['total'],
                      backgroundColor: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                      color: result['score'] == result['total']
                          ? correctColor
                          : result['score'] > result['total'] / 2
                          ? Colors.orange
                          : incorrectColor,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}