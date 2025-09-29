import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';

// Import your other screens
import 'saved_notes_screen.dart';
import 'quiz_results_screen.dart';
import 'flashcards_screen.dart';
import 'image_to_pdf_screen.dart';
import 'settings_screen.dart';
import 'home_screen.dart';

class MCQsHistoryScreen extends StatefulWidget {
  @override
  _MCQsHistoryScreenState createState() => _MCQsHistoryScreenState();
}

class _MCQsHistoryScreenState extends State<MCQsHistoryScreen> {
  List<Map<String, dynamic>> _mcqsHistory = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  int _selectedDrawerIndex = 2;
  List<int> _selectedSets = [];

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
    _loadMCQsHistory();
  }

  Future<void> _loadMCQsHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('mcqs_history') ?? [];
    setState(() {
      _mcqsHistory = history.map((item) {
        try {
          return Map<String, dynamic>.from(json.decode(item));
        } catch (e) {
          return {'topic': 'Invalid Data', 'questions': [], 'date': DateTime.now().toIso8601String()};
        }
      }).toList();
      _mcqsHistory.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
          _isLoading = false;
      });
  }

  String _sanitizeFilename(String input) {
    return input.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
  }

  Future<File> _generateSingleMCQSetPdf(Map<String, dynamic> mcqSet) async {
    final pdf = pw.Document();
    final topic = mcqSet['topic'] ?? 'MCQ Set';
    final date = DateTime.parse(mcqSet['date'] ?? DateTime.now().toIso8601String());
    final questions = List<dynamic>.from(mcqSet['questions'] ?? []);

    // Add cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  topic,
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '${questions.length} ${questions.length == 1 ? 'Question' : 'Questions'}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Generated on ${date.day}/${date.month}/${date.year}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Add content pages with continuous questions
    final content = pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                topic,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Text(
                    'Questions: ${questions.length}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    'Date: ${date.day}/${date.month}/${date.year}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 12),
              ...(questions.first is String
                  ? _buildPdfForOldFormat(List<String>.from(questions))
                  : _buildPdfForNewFormat(List<Map<String, dynamic>>.from(questions))),
            ],
          ),
        ];
      },
    );

    pdf.addPage(content);

    final output = await getTemporaryDirectory();
    final sanitizedTopic = _sanitizeFilename(topic);
    final file = File('${output.path}/$sanitizedTopic.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> _generateSelectedMCQSetsPdf(List<int> selectedIndices) async {
    final pdf = pw.Document();
    final selectedSets = selectedIndices.map((index) => _filteredHistory[index]).toList();

    // Add cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'StudyPal MCQs',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '${selectedSets.length} ${selectedSets.length == 1 ? 'Set' : 'Sets'}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Generated on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Add table of contents
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Table of Contents',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              ...selectedSets.asMap().entries.map((entry) {
                final index = entry.key;
                final mcqSet = entry.value;
                final topic = mcqSet['topic'] ?? 'MCQ Set ${index + 1}';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    '${index + 1}. $topic (Page ${index + 3})',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );

    // Add all selected MCQ sets with continuous questions
    for (final mcqSet in selectedSets) {
      final topic = mcqSet['topic'] ?? 'MCQ Set';
      final date = DateTime.parse(mcqSet['date'] ?? DateTime.now().toIso8601String());
      final questions = List<dynamic>.from(mcqSet['questions'] ?? []);

      final content = pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  topic,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Text(
                      'Questions: ${questions.length}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      'Date: ${date.day}/${date.month}/${date.year}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 12),
                ...(questions.first is String
                    ? _buildPdfForOldFormat(List<String>.from(questions))
                    : _buildPdfForNewFormat(List<Map<String, dynamic>>.from(questions))),
              ],
            ),
          ];
        },
      );

      pdf.addPage(content);
    }

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/StudyPal_MCQs_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> _generateAllMCQSetsPdf() async {
    final pdf = pw.Document();

    // Add cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'StudyPal MCQs Collection',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '${_filteredHistory.length} ${_filteredHistory.length == 1 ? 'Set' : 'Sets'}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Generated on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Add table of contents
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Table of Contents',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              ..._filteredHistory.asMap().entries.map((entry) {
                final index = entry.key;
                final mcqSet = entry.value;
                final topic = mcqSet['topic'] ?? 'MCQ Set ${index + 1}';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    '${index + 1}. $topic (Page ${index + 3})',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );

    // Add all MCQ sets with continuous questions
    for (final mcqSet in _filteredHistory) {
      final topic = mcqSet['topic'] ?? 'MCQ Set';
      final date = DateTime.parse(mcqSet['date'] ?? DateTime.now().toIso8601String());
      final questions = List<dynamic>.from(mcqSet['questions'] ?? []);

      final content = pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  topic,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Text(
                      'Questions: ${questions.length}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      'Date: ${date.day}/${date.month}/${date.year}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 12),
                ...(questions.first is String
                    ? _buildPdfForOldFormat(List<String>.from(questions))
                    : _buildPdfForNewFormat(List<Map<String, dynamic>>.from(questions))),
              ],
            ),
          ];
        },
      );

      pdf.addPage(content);
    }

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/StudyPal_All_MCQs_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> _showExportOptions() async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export Options', style: TextStyle(color: textColor)),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedSets.isNotEmpty)
              ListTile(
                leading: Icon(Icons.notes, color: theme.primaryColor),
                title: Text('Selected Sets (${_selectedSets.length})', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _handleSelectedSetsExport();
                },
              ),
            ListTile(
              leading: Icon(Icons.collections_bookmark, color: theme.primaryColor),
              title: Text('All Visible Sets (${_filteredHistory.length})', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _handleAllSetsExport();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAllSetsExport() async {
    if (_filteredHistory.isEmpty) {
      _showToast('No MCQs to export.');
      return;
    }

    var status = await Permission.storage.request();
    if (!status.isGranted) {
      _showToast('Storage permission is required to save PDF.');
      return;
    }

    _showToast('Generating PDF...');
    try {
      final file = await _generateAllMCQSetsPdf();
      await _saveAndOpenPdf(file);
    } catch (e) {
      _showToast('Error creating PDF: $e');
    }
  }

  Future<void> _handleSelectedSetsExport() async {
    if (_selectedSets.isEmpty) {
      _showToast('No sets selected.');
      return;
    }

    var status = await Permission.storage.request();
    if (!status.isGranted) {
      _showToast('Storage permission is required to save PDF.');
      return;
    }

    _showToast('Generating PDF...');
    try {
      final file = await _generateSelectedMCQSetsPdf(_selectedSets);
      await _saveAndOpenPdf(file);
    } catch (e) {
      _showToast('Error creating PDF: $e');
    }
  }

  Future<void> _saveAndOpenPdf(File tempFile) async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/StudyPal');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        _showToast('Could not access storage directory.');
        return;
      }

      final newPath = '${directory.path}/${tempFile.path.split('/').last}';
      final newFile = await tempFile.copy(newPath);

      _showToast('PDF saved in StudyPal folder');

      final openResult = await OpenFile.open(newFile.path);
      if (openResult.type != ResultType.done) {
        _showToast('Could not open file: ${openResult.message}');
      }
    } catch (e) {
      _showToast('Error saving file: $e');
    }
  }

  Future<void> _sharePDF(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'MCQs exported from StudyPal AI',
      );
    } catch (e) {
      _showToast('Error sharing file: $e');
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black.withOpacity(0.8),
      textColor: Colors.white,
    );
  }

  List<pw.Widget> _buildPdfForOldFormat(List<String> questions) {
    return questions.map((question) {
      final isQuestion = RegExp(r'^\d+[\).]').hasMatch(question.trim());
      final isCorrect = question.contains('[correct]');
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          isQuestion ? question : '• ${question.replaceAll('[correct]', '')}',
          style: pw.TextStyle(
            color: isCorrect ? PdfColors.green500 : PdfColors.black,
            fontWeight: isCorrect ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }).toList();
  }

  List<pw.Widget> _buildPdfForNewFormat(List<Map<String, dynamic>> questions) {
    return questions.map((questionData) {
      String questionText = questionData['question'] ?? 'N/A';
      List<String> options = List<String>.from(questionData['options'] ?? []);
      int correctOptionIndex = questionData['correct_option'] ?? -1;

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            questionText,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...options.asMap().entries.map((optionEntry) {
            int optIndex = optionEntry.key;
            String optionText = optionEntry.value;
            bool isCorrect = optIndex == correctOptionIndex;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(left: 15, top: 4),
              child: pw.Text(
                '• $optionText',
                style: pw.TextStyle(
                  color: isCorrect ? PdfColors.green500 : PdfColors.black,
                  fontWeight: isCorrect ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            );
          }).toList(),
          pw.SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  Future<void> _deleteMCQSet(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mcqsHistory.removeAt(index);
      _selectedSets.removeWhere((i) => i == index);
    });
    await prefs.setStringList('mcqs_history',
        _mcqsHistory.map((item) => json.encode(item)).toList()
    );
  }

  void _toggleSetSelection(int index) {
    setState(() {
      if (_selectedSets.contains(index)) {
        _selectedSets.remove(index);
      } else {
        _selectedSets.add(index);
      }
    });
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_searchController.text.isEmpty) return _mcqsHistory;
    return _mcqsHistory.where((item) {
      final topic = item['topic'].toString().toLowerCase();
      final searchTerm = _searchController.text.toLowerCase();
      return topic.contains(searchTerm);
    }).toList();
  }

  void _navigateToScreen(Widget screen, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (index == _selectedDrawerIndex) {
      Navigator.pop(context);
      return;
    }
    setState(() => _selectedDrawerIndex = index);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Theme(
          data: isDarkMode ? ThemeData.dark() : ThemeData.light(),
          child: screen,
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)],
                  ),
                  child: const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.school_rounded, size: 40, color: Colors.deepPurple),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('StudyPal AI', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Your Learning Companion', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
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
                color: isSelected ? (isDarkMode ? Colors.deepPurple.shade800.withOpacity(0.5) : Colors.deepPurple.withOpacity(0.1)) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  item['icon'],
                  color: isSelected ? Colors.deepPurple : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                ),
                title: Text(
                  item['title'],
                  style: TextStyle(
                    color: isSelected ? (isDarkMode ? Colors.white : Colors.deepPurple) : (isDarkMode ? Colors.white : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDarkMode ? Colors.white70 : Colors.deepPurple) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  if (item['screen'] != null) {
                    _navigateToScreen(item['screen'], index);
                  } else {
                    Navigator.pop(context);
                    setState(() => _selectedDrawerIndex = index);
                  }
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color topictextColor = isDarkMode ? Colors. amber: Colors.deepPurple;
    final Color primaryColor = isDarkMode ? Colors.white : Colors.deepPurple;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Search by topic...',
            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        )
            : Text('MCQs History', style: TextStyle(color: primaryColor)),
        iconTheme: IconThemeData(color: primaryColor),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: primaryColor),
            onPressed: _showExportOptions,
            tooltip: 'Export MCQs',
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: primaryColor),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _selectedSets.clear();
                }
              });
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _filteredHistory.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60, color: textColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No MCQs history yet' : 'No matching MCQs found',
              style: TextStyle(fontSize: 18, color: textColor.withOpacity(0.5)),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredHistory.length,
        itemBuilder: (context, index) {
          final mcqSet = _filteredHistory[index];
          final date = DateTime.parse(mcqSet['date'] ?? DateTime.now().toIso8601String());
          final questions = List<dynamic>.from(mcqSet['questions'] ?? []);
          final isSelected = _selectedSets.contains(index);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            color: isSelected
                ? (isDarkMode ? Colors.deepPurple.shade800.withOpacity(0.3) : Colors.deepPurple.withOpacity(0.1))
                : cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onLongPress: () => _toggleSetSelection(index),
              child: ExpansionTile(
                title: Text(
                  mcqSet['topic'] ?? 'Unknown Topic',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: topictextColor),
                ),
                subtitle: Text(
                  '${questions.length} questions • ${date.day}/${date.month}/${date.year}',
                  style: TextStyle(color: topictextColor),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Icon(Icons.check_circle, color: primaryColor),
                    IconButton(
                      icon: Icon(Icons.picture_as_pdf, color: topictextColor),
                      onPressed: () async {
                        final file = await _generateSingleMCQSetPdf(mcqSet);
                        await _saveAndOpenPdf(file);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red[400]),
                      onPressed: () async {
                        final shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete MCQs'),
                            content: const Text('Are you sure you want to delete this set of MCQs?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: primaryColor))),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (shouldDelete == true) {
                          final originalIndex = _mcqsHistory.indexWhere((item) => item['date'] == mcqSet['date'] && item['topic'] == mcqSet['topic']);
                          if (originalIndex != -1) _deleteMCQSet(originalIndex);
                        }
                      },
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (questions.isNotEmpty && questions.first is String)
                          ? _buildOldFormatWidgets(List<String>.from(questions))
                          : _buildNewFormatWidgets(List<Map<String, dynamic>>.from(questions)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildOldFormatWidgets(List<String> questions) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return questions.map((question) {
      final isQuestion = RegExp(r'^\d+[\).]').hasMatch(question.trim());
      final isCorrect = question.contains('[correct]');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          isQuestion ? question : '• ${question.replaceAll('[correct]', '')}',
          style: TextStyle(
            color: isCorrect ? (isDarkMode ? Colors.greenAccent : Colors.green) : textColor,
            fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildNewFormatWidgets(List<Map<String, dynamic>> questions) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return questions.asMap().entries.map((entry) {
      int qIndex = entry.key;
      Map<String, dynamic> questionData = entry.value;
      String questionText = questionData['question'] ?? 'No question text';
      List<String> options = List<String>.from(questionData['options'] ?? []);
      int correctOptionIndex = questionData['correct_option'] ?? -1;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${qIndex + 1}. $questionText",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...options.asMap().entries.map((optionEntry) {
              int optIndex = optionEntry.key;
              String optionText = optionEntry.value;
              bool isCorrect = optIndex == correctOptionIndex;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                child: Text(
                  "• $optionText",
                  style: TextStyle(
                    color: isCorrect ? (isDarkMode ? Colors.greenAccent : Colors.green) : textColor,
                    fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      );
    }).toList();
  }
}