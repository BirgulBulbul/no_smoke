
import 'package:flutter/material.dart';
import 'pages/survey_page.dart';

void main() {
  runApp(const NoSmokeApp());
}

class NoSmokeApp extends StatelessWidget {
  const NoSmokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'No Smoke',
      theme: ThemeData.dark(),
      home: const SurveyPage(),
    );
  }
}
