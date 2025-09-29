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
import 'mcqs_history_screen.dart';
import 'quiz_results_screen.dart';
import 'flashcards_screen.dart';
import 'image_to_pdf_screen.dart';
import 'settings_screen.dart';
import 'home_screen.dart';

class SavedNotesScreen extends StatefulWidget {
  const SavedNotesScreen({Key? key}) : super(key: key);

  @override
  State<SavedNotesScreen> createState() => _SavedNotesScreenState();
}

class _SavedNotesScreenState extends State<SavedNotesScreen> {
  List<Map<String, dynamic>> _savedNotes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  int _selectedDrawerIndex = 1;
  List<int> _selectedNotes = [];

  final List<Map<String, dynamic>> _drawerItems = [
    {'title': 'Home', 'icon': Icons.home_filled, 'screen': const HomeScreen()},
    {'title': 'Saved Notes', 'icon': Icons.bookmark_added_rounded, 'screen': null},
    {'title': 'MCQs History', 'icon': Icons.history_edu_rounded, 'screen': MCQsHistoryScreen()},
    {'title': 'Quiz Results', 'icon': Icons.analytics_rounded, 'screen': QuizResultScreen()},
    {'title': 'Flashcards', 'icon': Icons.flash_on_rounded, 'screen': FlashcardsScreen()},
    {'title': 'Image to PDF', 'icon': Icons.picture_as_pdf_rounded, 'screen': ImageToPdfScreen()},
    {'title': 'Settings', 'icon': Icons.settings_rounded, 'screen': SettingsScreen()},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedNotes();
  }

  Future<void> _loadSavedNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notes = prefs.getStringList('saved_notes') ?? [];
    setState(() {
      _savedNotes = notes.map((note) {
        try {
          return Map<String, dynamic>.from(json.decode(note));
        } catch (e) {
          return {'content': note, 'date': DateTime.now().toIso8601String(), 'type': 'Note'};
        }
      }).toList();
      _savedNotes.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
          _isLoading = false;
      });
  }

  Future<File> _generatePdf(List<Map<String, dynamic>> notes) async {
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
                  'StudyPal Notes',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '${notes.length} ${notes.length == 1 ? 'Note' : 'Notes'}',
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

    // Add all notes
    for (final note in notes) {
      final topic = note['topic'] ?? 'Note';
      final content = note['content'] ?? 'No content';
      final type = note['type'] ?? 'General';
      final date = DateTime.parse(note['date'] ?? DateTime.now().toIso8601String());

      // Calculate how many pages we need for this note
      final contentParts = _splitContentForPdf(content);

      for (int i = 0; i < contentParts.length; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (i == 0) ...[
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
                          type,
                          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          '${date.day}/${date.month}/${date.year}',
                          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                  ],
                  pw.Text(
                    contentParts[i],
                    style: pw.TextStyle(fontSize: 12, lineSpacing: 2),
                    textAlign: pw.TextAlign.justify,
                  ),
                  if (i == contentParts.length - 1) ...[
                    pw.SizedBox(height: 20),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Generated by StudyPal AI',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }
    }

    final output = await getTemporaryDirectory();
    final fileName = notes.length == 1
        ? 'StudyPal_${_sanitizeFilename(notes[0]['topic'] ?? 'Note')}.pdf'
        : 'StudyPal_Notes_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  List<String> _splitContentForPdf(String content) {
    const maxCharsPerPage = 2500; // Approximate characters per PDF page
    List<String> parts = [];

    if (content.length <= maxCharsPerPage) {
      parts.add(content);
      return parts;
    }

    int start = 0;
    while (start < content.length) {
      int end = (start + maxCharsPerPage).clamp(0, content.length);
      // Try to split at paragraph if possible
      if (end < content.length) {
        int lastNewLine = content.lastIndexOf('\n', end);
        if (lastNewLine > start) {
          end = lastNewLine;
        }
      }
      parts.add(content.substring(start, end));
      start = end;
    }

    return parts;
  }

  String _sanitizeFilename(String input) {
    return input.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
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
            if (_selectedNotes.isNotEmpty)
              ListTile(
                leading: Icon(Icons.notes, color: theme.primaryColor),
                title: Text('Selected Notes (${_selectedNotes.length})', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _exportSelectedNotes();
                },
              ),
            ListTile(
              leading: Icon(Icons.collections_bookmark, color: theme.primaryColor),
              title: Text('All Visible Notes (${_filteredNotes.length})', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _exportAllNotes();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSelectedNotes() async {
    if (_selectedNotes.isEmpty) {
      _showToast('No notes selected.');
      return;
    }

    var status = await Permission.storage.request();
    if (!status.isGranted) {
      _showToast('Storage permission is required to save PDF.');
      return;
    }

    _showToast('Generating PDF...');
    try {
      final selectedNotes = _selectedNotes.map((index) => _filteredNotes[index]).toList();
      final file = await _generatePdf(selectedNotes);
      await _saveAndOpenPdf(file);
    } catch (e) {
      _showToast('Error creating PDF: $e');
    }
  }

  Future<void> _exportAllNotes() async {
    if (_filteredNotes.isEmpty) {
      _showToast('No notes to export.');
      return;
    }

    var status = await Permission.storage.request();
    if (!status.isGranted) {
      _showToast('Storage permission is required to save PDF.');
      return;
    }

    _showToast('Generating PDF...');
    try {
      final file = await _generatePdf(_filteredNotes);
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
        text: 'Notes exported from StudyPal AI',
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

  Future<void> _deleteNote(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedNotes.removeAt(index);
      _selectedNotes.removeWhere((i) => i == index);
    });
    await prefs.setStringList('saved_notes', _savedNotes.map((note) => json.encode(note)).toList());
  }

  Future<bool?> _confirmDelete(int index) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Note', style: TextStyle(color: textColor)),
        content: Text('Are you sure you want to delete this note?', style: TextStyle(color: textColor)),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: theme.primaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleNoteSelection(int index) {
    setState(() {
      if (_selectedNotes.contains(index)) {
        _selectedNotes.remove(index);
      } else {
        _selectedNotes.add(index);
      }
    });
  }

  Widget _buildDrawer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = Theme.of(context);
    final Color iconColor = isDarkMode ? Colors.white70 : Colors.grey[700]!;
    final Color selectedIconColor = isDarkMode ? Colors.white : Colors.deepPurple;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color selectedTextColor = isDarkMode ? Colors.white : Colors.deepPurple;

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
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.school_rounded, size: 40, color: Colors.deepPurple),
                  ),
                ),
                const SizedBox(height: 16),
                Text('StudyPal AI', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                color: isSelected
                    ? (isDarkMode
                    ? Colors.deepPurple.shade800.withOpacity(0.5)
                    : Colors.deepPurple.withOpacity(0.1))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  item['icon'],
                  color: isSelected ? selectedIconColor : iconColor,
                ),
                title: Text(
                  item['title'],
                  style: TextStyle(
                    color: isSelected ? selectedTextColor : textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isSelected ? selectedIconColor : iconColor)
                    : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  if (item['screen'] != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Theme(
                          data: currentTheme,
                          child: item['screen'],
                        ),
                      ),
                    );
                  } else {
                    setState(() => _selectedDrawerIndex = index);
                    Navigator.pop(context);
                  }
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredNotes {
    if (_searchController.text.isEmpty) return _savedNotes;
    return _savedNotes
        .where((note) {
      final content = note['content'].toString().toLowerCase();
      final topic = note['topic']?.toString().toLowerCase() ?? '';
      return content.contains(_searchController.text.toLowerCase()) ||
          topic.contains(_searchController.text.toLowerCase());
    })
        .toList();
  }

  String _getNotePreview(String content) {
    final firstLine = content.split('\n').first;
    return firstLine.length > 50 ? '${firstLine.substring(0, 50)}...' : firstLine;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.deepPurple;
    final Color topictextColor = isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple;
    final Color primaryColor = isDarkMode ? Colors.white : Colors.black;
    final Color appBarIconColor = isDarkMode ? Colors.white : Colors.deepPurple;
    final Color chipTextColor = isDarkMode ? Colors.white : Colors.white;

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Search notes...',
            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        )
            : Text('Saved Notes', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        elevation: 0,
        actions: [
          if (_savedNotes.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.picture_as_pdf, color: appBarIconColor),
              onPressed: _showExportOptions,
              tooltip: 'Export Notes',
            ),
          ],
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: appBarIconColor),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _selectedNotes.clear();
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _filteredNotes.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_add_outlined, size: 60, color: textColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No saved notes yet' : 'No matching notes found',
              style: TextStyle(fontSize: 18, color: textColor.withOpacity(0.5)),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // You might want to navigate to the note creation screen here
                },
                child: Text('Create your first note', style: TextStyle(color: primaryColor)),
              ),
            ],
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredNotes.length,
        itemBuilder: (context, index) {
          final note = _filteredNotes[index];
          final date = DateTime.tryParse(note['date']?.toString() ?? '') ?? DateTime.now();
          final notePreview = _getNotePreview(note['content'].toString());
          final topic = note['topic'] ?? notePreview;
          final isSelected = _selectedNotes.contains(index);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            color: isSelected
                ? (isDarkMode ? Colors.deepPurple.shade800.withOpacity(0.3) : Colors.deepPurple.withOpacity(0.1))
                : cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onLongPress: () => _toggleNoteSelection(index),
              onTap: () {
                if (_selectedNotes.isNotEmpty) {
                  _toggleNoteSelection(index);
                } else {
                  _showNoteDetails(note);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_selectedNotes.isNotEmpty)
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleNoteSelection(index),
                            activeColor: Colors.deepPurple,
                          ),
                        Expanded(
                          child: Text(
                            topic,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: topictextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            note['type']?.toString() ?? 'Note',
                            style: TextStyle(
                              fontSize: 12,
                              color: chipTextColor,
                            ),
                          ),
                          backgroundColor: isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${date.day}/${date.month}/${date.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: topictextColor,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.picture_as_pdf, size: 20, color: topictextColor),
                          tooltip: 'Save as PDF',
                          onPressed: () async {
                            final file = await _generatePdf([note]);
                            await _saveAndOpenPdf(file);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, size: 20, color: Colors.red[400]),
                          onPressed: () async {
                            final noteIndex = _savedNotes.indexWhere(
                                  (n) => n['date'] == note['date'] && n['content'] == note['content'],
                            );
                            if (noteIndex != -1) {
                              final shouldDelete = await _confirmDelete(noteIndex);
                              if (shouldDelete == true) _deleteNote(noteIndex);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNoteDetails(Map<String, dynamic> note) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color topictextColor = isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple;
    final Color backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final date = DateTime.tryParse(note['date']?.toString() ?? '') ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              note['topic'] ?? 'Note',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: topictextColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(
                    note['type']?.toString() ?? 'Note',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                const SizedBox(width: 8),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: topictextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  note['content'].toString(),
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Close', style: TextStyle(color: textColor)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? Colors.deepPurple : Colors.deepPurple,
                  ),
                  onPressed: () async {
                    final file = await _generatePdf([note]);
                    await _saveAndOpenPdf(file);
                  },
                  child: const Text('Export as PDF', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}