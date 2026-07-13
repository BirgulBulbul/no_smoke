
import 'package:flutter/material.dart';

class WeeklySurveyPage extends StatelessWidget {
  const WeeklySurveyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Haftalık Anket"),
      ),
      body: const Center(
        child: Text(
          "Haftalık Anket Sayfası",
        ),
      ),
    );
  }
}
