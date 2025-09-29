import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'formula_page.dart';
import 'image_to_pdf_screen.dart';
import 'mcqs_page.dart';
import 'quiz_screen.dart';
import 'notes_screen.dart';
import 'saved_notes_screen.dart';
import 'mcqs_history_screen.dart';
import 'flashcards_screen.dart';
import 'settings_screen.dart';
import 'quiz_results_screen.dart';
import 'ai_assistant_screen.dart';

void main() {
  runApp(const StudyPalApp());
}

class StudyPalApp extends StatelessWidget {
  const StudyPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyPal AI',
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF7F6FB),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Colors.deepPurple,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.deepPurple),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDarkMode = false;
  double _progressValue = 0.0;
  final List<String> _studyTips = [
    "Revise previous material within 24 hours to improve retention by up to 80%.",
    "Active recall boosts memory retention. Test yourself on yesterday's material.",
    "Study in 25-minute blocks with 5-minute breaks (Pomodoro Technique).",
    "Explain concepts out loud as if teaching someone else.",
    "Mix different subjects in a single study session for better learning.",
    "Use mnemonics and visualization to remember complex information."
  ];
  String _currentTip = "";
  int _selectedDrawerIndex = 0;

  final List<Map<String, dynamic>> _drawerItems = [
    {'title': 'Home', 'icon': Icons.home_filled, 'screen': null},
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
    _loadProgress();
    _loadThemePreference();
    _updateDailyTip();
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

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _progressValue = prefs.getDouble('progressValue') ?? 0.0;
    });
  }

  void _updateDailyTip() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    setState(() {
      _currentTip = _studyTips[dayOfYear % _studyTips.length];
    });
  }

  Future<void> _updateProgress(double newValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('progressValue', newValue);
    setState(() {
      _progressValue = newValue;
    });
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
    ).then((_) {
      // Reset the selected index to 0 (Home) when returning to this screen.
      setState(() {
        _selectedDrawerIndex = 0;
      });
    });
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
    return Theme(
      data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        drawer: _buildDrawer(),
        appBar: AppBar(
          iconTheme: IconThemeData(
            color: _isDarkMode ? Colors.white : Colors.deepPurple,
          ),
          title: Text(
            'StudyPal AI',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.deepPurple,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Icon(
              _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
              color: _isDarkMode ? Colors.amber : Colors.deepPurple,
            ),

            const SizedBox(width: 8),
            Switch(
              value: _isDarkMode,
              onChanged: _toggleTheme,
              activeColor: Colors.amber,
              inactiveThumbColor: Colors.deepPurple,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.school,
                  size: 100,
                  color: _isDarkMode
                      ? Colors.deepPurpleAccent.shade200
                      : Colors.deepPurple.withOpacity(0.9),
                ),
                const SizedBox(height: 28),
                _buildFeatureButtons(),
                const SizedBox(height: 32),
                _buildProgressCard(),
                const SizedBox(height: 20),
                _buildTipCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureButtons() {
    return Column(
      children: [
        _buildFeatureButton("📝 AI Notes Generator", Colors.deepPurple, () => _navigateToScreen(const NotesScreen(), 0)),
        const SizedBox(height: 16),
        _buildFeatureButton("📚 AI MCQs Generator", Colors.purple, () => _navigateToScreen(MCQsPage(), 0)),
        const SizedBox(height: 16),
        _buildFeatureButton("❓ AI Quiz Generator", Colors.indigo, () => _navigateToScreen(QuizPage(), 0)),
        const SizedBox(height: 16),
        _buildFeatureButton("📘 Formulas & Questions", Colors.teal, () => _navigateToScreen(FormulaScreen(), 0)),
      ],
    );
  }

  Widget _buildFeatureButton(String title, Color color, VoidCallback onTap) {
    return Material(
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_isDarkMode ? 0.3 : 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return GestureDetector(
      onTap: _showProgressDialog,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 28, color: _isDarkMode ? Colors.amber : Colors.deepPurple),
                const SizedBox(width: 12),
                Text(
                  'Learning Progress',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.white : Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progressValue,
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(_isDarkMode ? Colors.amber : Colors.deepPurple),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Weekly Goal', style: TextStyle(fontSize: 12, color: _isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                Text('${(_progressValue * 100).toStringAsFixed(0)}% Complete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.amber : Colors.deepPurple)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode ? [Colors.deepPurple.shade700, Colors.purple.shade700] : [Colors.deepPurpleAccent, Colors.purpleAccent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.deepPurple.withOpacity(0.4) : Colors.purple.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, size: 24, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Daily Study Tip',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentTip,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _showProgressDialog() async {
    double newValue = _progressValue;
    await showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
            textTheme: Theme.of(context).textTheme.copyWith(
              titleMedium: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
              bodyMedium: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
            ),
          ),
          child: AlertDialog(
            title: const Text("Update Progress"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Set your weekly learning progress:"),
                const SizedBox(height: 20),
                Slider(
                  value: newValue,
                  onChanged: (value) {
                    setState(() => newValue = value);
                  },
                  min: 0,
                  max: 1,
                  divisions: 10,
                  label: "${(newValue * 100).round()}%",
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: _isDarkMode ? Colors.amber : Colors.deepPurple)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDarkMode ? Colors.amber : Colors.deepPurple,
                ),
                onPressed: () {
                  _updateProgress(newValue);
                  Navigator.pop(context);
                },
                child: const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}