import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studypalai/home_screen.dart';
import 'package:studypalai/quiz_results_screen.dart';

// Import your other screens here
import 'saved_notes_screen.dart';
import 'mcqs_history_screen.dart';
import 'quiz_result_screen.dart';
import 'flashcards_screen.dart';
import 'settings_screen.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({Key? key}) : super(key: key);

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  List<File> _selectedImages = [];
  final TextEditingController _fileNameController = TextEditingController();
  bool _isProcessing = false;
  bool _isDarkMode = false;
  int _selectedDrawerIndex = 5; // Image to PDF is at index 5 in drawer items

  final List<Map<String, dynamic>> _drawerItems = [
    {'title': 'Home', 'icon': Icons.home_filled, 'screen': HomeScreen()},
    {'title': 'Saved Notes', 'icon': Icons.bookmark_added_rounded, 'screen': SavedNotesScreen()},
    {'title': 'MCQs History', 'icon': Icons.history_edu_rounded, 'screen': MCQsHistoryScreen()},
    {'title': 'Quiz Results', 'icon': Icons.analytics_rounded, 'screen': QuizResultScreen()},
    {'title': 'Flashcards', 'icon': Icons.flash_on_rounded, 'screen': FlashcardsScreen()},
    {'title': 'Image to PDF', 'icon': Icons.picture_as_pdf_rounded, 'screen': null},
    {'title': 'Settings', 'icon': Icons.settings_rounded, 'screen': SettingsScreen()},
  ];

  @override
  void initState() {
    super.initState();
    _fileNameController.text = 'StudyPal_${DateTime.now().millisecondsSinceEpoch}';
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

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await ImagePicker().pickMultiImage(
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (images != null && images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((xfile) => File(xfile.path)).toList());
        });
      }
    } on PlatformException catch (e) {
      _showErrorNotification('Failed to pick images: ${e.message}');
    }
  }

  Future<void> _createPdf() async {
    if (_selectedImages.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final pdf = pw.Document();

      // Add each image as a full page in the PDF
      for (final imageFile in _selectedImages) {
        final image = pw.MemoryImage(imageFile.readAsBytesSync());
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      // Get the downloads directory
      final directory = Directory('/storage/emulated/0/Download/StudyPal');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Save the PDF file
      final file = File('${directory.path}/${_fileNameController.text}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Show success notification
      _showSuccessNotification(file);

    } catch (e) {
      _showErrorNotification('Error creating PDF: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccessNotification(File file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.green[800] : Colors.green[600],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PDF Created Successfully!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved to StudyPal folder in Downloads',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => OpenFile.open(file.path),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 180,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 4),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showErrorNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.red[800] : Colors.red[600],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PDF Creation Failed',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.length > 50 ? '${message.substring(0, 50)}...' : message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 180,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 4),
        padding: EdgeInsets.zero,
      ),
    );
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
    return Theme(
      data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        drawer: _buildDrawer(),
        appBar: AppBar(
          title: const Text('Image to PDF'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(
            color: _isDarkMode ? Colors.white : Colors.deepPurple,
          ),
          actions: [
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: _isProcessing ? null : _createPdf,
                tooltip: 'Create PDF',
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _fileNameController,
                decoration: InputDecoration(
                  labelText: 'PDF File Name',
                  labelStyle: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isDarkMode ? Colors.amber : Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
                ),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            Expanded(
              child: _selectedImages.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image,
                      size: 60,
                      color: _isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No images selected',
                      style: TextStyle(
                        fontSize: 18,
                        color: _isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _pickImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDarkMode ? Colors.deepPurple : Colors.deepPurpleAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Select Images'),
                    ),
                  ],
                ),
              )
                  : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Image.file(
                        _selectedImages[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}/${_selectedImages.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_selectedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _pickImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDarkMode ? Colors.deepPurple : Colors.deepPurpleAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add More Images'),
                    ),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _createPdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDarkMode ? Colors.amber : Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text('Create PDF'),
                    ),
                  ],
                ),
              ),
          ],
        ),
        floatingActionButton: _selectedImages.isEmpty
            ? FloatingActionButton(
          onPressed: _pickImages,
          backgroundColor: _isDarkMode ? Colors.deepPurple : Colors.deepPurpleAccent,
          child: const Icon(Icons.add_a_photo),
        )
            : null,
      ),
    );
  }
}