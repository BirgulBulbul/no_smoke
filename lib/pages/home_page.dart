import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String name;
  final int riskScore;
  final String riskLevel;

  const HomePage({
    super.key,
    required this.name,
    required this.riskScore,
    required this.riskLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hoş geldin, $name',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Risk seviyesi: $riskLevel',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Risk skoru: $riskScore / 100',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Başa Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
