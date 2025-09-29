import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // For Clipboard functionality
import 'home_screen.dart';
import 'image_to_pdf_screen.dart';
import 'quiz_results_screen.dart';
import 'saved_notes_screen.dart';
import 'mcqs_history_screen.dart';
import 'settings_screen.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({Key? key}) : super(key: key);

  @override
  _AIAssistantScreenState createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // Changed to dynamic to include id
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  bool _isDarkMode = false;
  int _editingMessageId = -1; // Track which message is being edited
  TextEditingController _editController = TextEditingController();
  int _replyingToMessageId = -1; // Track which message we're replying to after edit

  // Your API key hardcoded
  final String _apiKey = "api key";

  // Drawer items (same as homepage)
  final List<Map<String, dynamic>> _drawerItems = [
    {'title': 'Home', 'icon': Icons.home_filled, 'screen': HomeScreen()},
    {'title': 'Saved Notes', 'icon': Icons.bookmark_added_rounded, 'screen': SavedNotesScreen()},
    {'title': 'MCQs History', 'icon': Icons.history_edu_rounded, 'screen': MCQsHistoryScreen()},
    {'title': 'Quiz Results', 'icon': Icons.analytics_rounded, 'screen': QuizResultScreen()},
    {'title': 'Flashcards', 'icon': Icons.flash_on_rounded, 'screen': null},
    {'title': 'Image to PDF', 'icon': Icons.picture_as_pdf_rounded, 'screen': ImageToPdfScreen()},
    {'title': 'Settings', 'icon': Icons.settings_rounded, 'screen': SettingsScreen()},
  ];
  int _selectedDrawerIndex = 4; // Flashcards is selected (index 4)

  @override
  void initState() {
    super.initState();
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

  // Get current time for real-time information
  String _getCurrentTime() {
    return DateTime.now().toString().substring(11, 16);
  }

  // Get current date for real-time information
  String _getCurrentDate() {
    return DateTime.now().toString().substring(0, 10);
  }

  Future<String> _sendMessageToAI(String message) async {
    const apiUrl = "https://openrouter.ai/api/v1/chat/completions";

    // Handle real-time queries locally
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('time')) {
      return "The current time is ${_getCurrentTime()}.";
    }

    if (lowerMessage.contains('date')) {
      return "Today's date is ${_getCurrentDate()}.";
    }

    if (lowerMessage.contains('weather')) {
      return "I can provide general weather information, but for real-time data you'll need to use a dedicated weather service.";
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
          "HTTP-Referer": "https://studypal.com", // Required by OpenRouter
          "X-Title": "StudyPal AI", // Required by OpenRouter
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": [
            {"role": "user", "content": message}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["choices"][0]["message"]["content"].trim();
      } else if (response.statusCode == 401) {
        return "API Error: Invalid API key. Please contact support.";
      } else {
        return "Error: ${response.statusCode}. Please try again later.";
      }
    } catch (e) {
      return "Failed to connect: Please check your internet connection.";
    }
  }

  void _sendMessage({String? editedMessage, int? replyToId}) async {
    String message;
    bool isEdit = false;

    if (editedMessage != null && replyToId != null) {
      message = editedMessage;
      isEdit = true;

      // Remove any existing AI response to this message
      _messages.removeWhere((msg) => msg["id"] == replyToId + 1 && msg["role"] == "ai");
    } else {
      if (_controller.text.trim().isEmpty) return;
      message = _controller.text.trim();
      _controller.clear();
    }

    setState(() {
      if (isEdit) {
        // Update the existing message
        final index = _messages.indexWhere((msg) => msg["id"] == replyToId);
        if (index != -1) {
          _messages[index]["text"] = message;
        }
      } else {
        // Add new message
        _messages.add({
          "id": DateTime.now().millisecondsSinceEpoch,
          "role": "user",
          "text": message
        });
      }
      _isLoading = true;
      _editingMessageId = -1;
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    final aiResponse = await _sendMessageToAI(message);

    setState(() {
      _messages.add({
        "id": DateTime.now().millisecondsSinceEpoch + 1,
        "role": "ai",
        "text": aiResponse,
        "replyTo": isEdit ? replyToId : null, // Track if this is a reply to an edited message
      });
      _isLoading = false;
      _replyingToMessageId = -1;
    });

    // Scroll to bottom after response
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _deleteMessage(int id) {
    setState(() {
      _messages.removeWhere((msg) => msg["id"] == id);
    });
  }

  void _startEditing(int id, String text) {
    setState(() {
      _editingMessageId = id;
      _editController.text = text;
    });
  }

  void _finishEditing() {
    if (_editController.text.trim().isNotEmpty) {
      setState(() {
        _replyingToMessageId = _editingMessageId;
        _editingMessageId = -1;
      });

      // Send the edited message to AI
      _sendMessage(
        editedMessage: _editController.text.trim(),
        replyToId: _replyingToMessageId,
      );

      _editController.clear();
    } else {
      setState(() {
        _editingMessageId = -1;
        _editController.clear();
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: _isDarkMode ? Colors.deepPurple[700] : Colors.deepPurple,
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
                  if (index == 0) {
                    Navigator.pop(context); // Go back to home
                  } else if (item['screen'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => item['screen']),
                    );
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

  Widget _buildMessageOptions(int id, String text, bool isUser) {
    return PopupMenuButton<String>(
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.content_copy, size: 20, color: _isDarkMode ? Colors.white70 : Colors.grey[700]),
              SizedBox(width: 8),
              Text('Copy', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87)),
            ],
          ),
        ),
        if (isUser) PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20, color: _isDarkMode ? Colors.white70 : Colors.grey[700]),
              SizedBox(width: 8),
              Text('Edit', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'copy') {
          _copyToClipboard(text);
        } else if (value == 'edit' && isUser) {
          _startEditing(id, text);
        } else if (value == 'delete') {
          _deleteMessage(id);
        }
      },
      icon: Icon(
        Icons.more_vert,
        color: _isDarkMode ? Colors.white54 : Colors.grey[600],
        size: 20,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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
            'AI Assistant',
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
        body: Container(
          color: _isDarkMode ? Colors.grey[900] : const Color(0xFFF7F6FB),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg["role"] == "user";
                    final id = msg["id"] as int;
                    final text = msg["text"] as String;

                    // Check if this message is being edited
                    final isEditing = _editingMessageId == id;

                    return Row(
                      mainAxisAlignment: isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isUser)
                          CircleAvatar(
                            backgroundColor: _isDarkMode
                                ? Colors.deepPurple[700]
                                : Colors.deepPurple[200],
                            child: const Text("AI",
                                style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? (_isDarkMode
                                  ? Colors.deepPurple[600]
                                  : Colors.deepPurple[400])
                                  : (_isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isEditing)
                                  Column(
                                    children: [
                                      TextField(
                                        controller: _editController,
                                        maxLines: null,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isUser
                                              ? Colors.white
                                              : (_isDarkMode
                                              ? Colors.white
                                              : Colors.black87),
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                          border: InputBorder.none,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _editingMessageId = -1;
                                                _editController.clear();
                                              });
                                            },
                                            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                                          ),
                                          SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: _finishEditing,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _isDarkMode ? Colors.deepPurple[600] : Colors.deepPurple[400],
                                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            ),
                                            child: Text('Save', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    text,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isUser
                                          ? Colors.white
                                          : (_isDarkMode
                                          ? Colors.white
                                          : Colors.black87),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (!isEditing) const SizedBox(width: 8),
                        if (!isEditing) _buildMessageOptions(id, text, isUser),
                        if (isUser) const SizedBox(width: 8),
                        if (isUser && !isEditing)
                          CircleAvatar(
                            backgroundColor: _isDarkMode
                                ? Colors.deepPurple[700]
                                : Colors.deepPurple[200],
                            child: const Icon(Icons.person, size: 18, color: Colors.white),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: _isDarkMode
                            ? Colors.deepPurple[700]
                            : Colors.deepPurple[200],
                        child: const Text("AI",
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isDarkMode
                                      ? Colors.deepPurple[200]!
                                      : Colors.deepPurple[600]!,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Thinking...",
                              style: TextStyle(
                                color: _isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                color: _isDarkMode
                    ? Colors.grey[800]
                    : Colors.grey[200],
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: "Ask me anything...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: _isDarkMode
                              ? Colors.grey[700]
                              : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: _isDarkMode
                          ? Colors.deepPurple[700]
                          : Colors.deepPurple,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () => _sendMessage(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
