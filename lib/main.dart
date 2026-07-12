
import 'package:flutter/material.dart';

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

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController cigaretteController = TextEditingController();

  String gender = "Erkek";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NO SMOKE"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            const Text(
              "Başlangıç Profili",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Adınız",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Yaşınız",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: gender,
              decoration: const InputDecoration(
                labelText: "Cinsiyet",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: "Erkek",
                  child: Text("Erkek"),
                ),
                DropdownMenuItem(
                  value: "Kadın",
                  child: Text("Kadın"),
                ),
                DropdownMenuItem(
                  value: "Belirtmek İstemiyorum",
                  child: Text("Belirtmek İstemiyorum"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  gender = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            TextField(
              controller: cigaretteController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Günlük Sigara Sayisi",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Merhaba ${nameController.text}, profil oluşturuldu.",
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Profili Oluştur",
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
