import 'package:flutter/material.dart';
import 'package:studypalai/ai_assistant_screen.dart';
import 'splash_screen.dart'; // 👈 Import splash screen

void main() {
  runApp(StudyPalApp());
}

class StudyPalApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyPal AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Montserrat',
      ),
      home: SplashScreen(), // 👈 Show splash screen first
    );
  }
}
