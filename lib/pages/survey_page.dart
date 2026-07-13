import 'package:flutter/material.dart';

import 'breath_test_page.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController cigarettesController = TextEditingController();
  final TextEditingController smokingYearsController = TextEditingController();
  final TextEditingController workStartController = TextEditingController();
  final TextEditingController workEndController = TextEditingController();

  String gender = 'Erkek';
  String firstCigaretteRange = '10-30';
  String smokeFreeRange = '30-60';
  String workplaceSmokingRule = 'Hayır';
  String stressLevel = 'Orta';
  String quitReason = 'Sağlık';
  String sleepTime = '21:00';
  String wakeTime = '07:00';

  bool hypertension = false;
  bool asthma = false;
  bool diabetes = false;
  bool copd = false;
  bool heartDisease = false;

  final Set<String> triggerSet = <String>{};

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget triggerTile(String title, String key) {
    return CheckboxListTile(
      dense: true,
      value: triggerSet.contains(key),
      title: Text(title),
      onChanged: (value) {
        setState(() {
          if (value == true) {
            triggerSet.add(key);
          } else {
            triggerSet.remove(key);
          }
        });
      },
    );
  }

  List<String> get timeOptions {
    return List.generate(
      48,
      (index) {
        final hour = (index ~/ 2).toString().padLeft(2, '0');
        final minute = index.isEven ? '00' : '30';
        return '$hour:$minute';
      },
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    cigarettesController.dispose();
    smokingYearsController.dispose();
    workStartController.dispose();
    workEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NO SMOKE'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Başlangıç Anketi',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Ad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Yaş',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(
                labelText: 'Cinsiyet',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Erkek', child: Text('Erkek')),
                DropdownMenuItem(value: 'Kadın', child: Text('Kadın')),
              ],
              onChanged: (value) {
                setState(() {
                  gender = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            sectionTitle('Sigara Bilgileri'),
            TextField(
              controller: cigarettesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Günlük Sigara Sayısı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: firstCigaretteRange,
              decoration: const InputDecoration(
                labelText: 'İlk sigara ne zaman?',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '0-5', child: Text('0-5 dakika')),
                DropdownMenuItem(value: '5-10', child: Text('5-10 dakika')),
                DropdownMenuItem(value: '10-30', child: Text('10-30 dakika')),
                DropdownMenuItem(value: '30-60', child: Text('30-60 dakika')),
                DropdownMenuItem(value: '60+', child: Text('60 dakika ve üzeri')),
              ],
              onChanged: (value) {
                setState(() {
                  firstCigaretteRange = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: smokeFreeRange,
              decoration: const InputDecoration(
                labelText: 'En fazla ne kadar sigarasız kalabiliyorsunuz?',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '0-15', child: Text('0-15 dakika')),
                DropdownMenuItem(value: '15-30', child: Text('15-30 dakika')),
                DropdownMenuItem(value: '30-60', child: Text('30-60 dakika')),
                DropdownMenuItem(value: '60-120', child: Text('1-2 saat')),
                DropdownMenuItem(value: '120-240', child: Text('2-4 saat')),
                DropdownMenuItem(value: '240+', child: Text('4 saat ve üzeri')),
              ],
              onChanged: (value) {
                setState(() {
                  smokeFreeRange = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: smokingYearsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kaç yıldır sigara içiyorsunuz?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            sectionTitle('Yaşam Düzeni'),
            DropdownButtonFormField<String>(
              initialValue: sleepTime,
              decoration: const InputDecoration(
                labelText: 'Uyku saati',
                border: OutlineInputBorder(),
              ),
              items: timeOptions
                  .map(
                    (time) => DropdownMenuItem<String>(
                      value: time,
                      child: Text(time),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  sleepTime = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: wakeTime,
              decoration: const InputDecoration(
                labelText: 'Uyanma saati',
                border: OutlineInputBorder(),
              ),
              items: timeOptions
                  .map(
                    (time) => DropdownMenuItem<String>(
                      value: time,
                      child: Text(time),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  wakeTime = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: workStartController,
              decoration: const InputDecoration(
                labelText: 'Çalışma başlangıç saati',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: workEndController,
              decoration: const InputDecoration(
                labelText: 'Çalışma bitiş saati',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: workplaceSmokingRule,
              decoration: const InputDecoration(
                labelText: 'İş yerinde sigara içilebiliyor mu?',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Evet', child: Text('Evet')),
                DropdownMenuItem(value: 'Hayır', child: Text('Hayır')),
                DropdownMenuItem(value: 'Sadece molalarda', child: Text('Sadece molalarda')),
              ],
              onChanged: (value) {
                setState(() {
                  workplaceSmokingRule = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            sectionTitle('Sağlık Durumu'),
            CheckboxListTile(
              value: hypertension,
              title: const Text('Hipertansiyon'),
              onChanged: (value) => setState(() => hypertension = value ?? false),
            ),
            CheckboxListTile(
              value: asthma,
              title: const Text('Astım'),
              onChanged: (value) => setState(() => asthma = value ?? false),
            ),
            CheckboxListTile(
              value: diabetes,
              title: const Text('Diyabet'),
              onChanged: (value) => setState(() => diabetes = value ?? false),
            ),
            CheckboxListTile(
              value: copd,
              title: const Text('KOAH'),
              onChanged: (value) => setState(() => copd = value ?? false),
            ),
            CheckboxListTile(
              value: heartDisease,
              title: const Text('Kalp Hastalığı'),
              onChanged: (value) => setState(() => heartDisease = value ?? false),
            ),
            const SizedBox(height: 20),
            sectionTitle('Sigara Tetikleyicileri'),
            triggerTile('Kahve içerken', 'coffee'),
            triggerTile('Yemek sonrası', 'meal'),
            triggerTile('Araç kullanırken', 'driving'),
            triggerTile('Stresliyken', 'stress'),
            triggerTile('Telefonda konuşurken', 'phone'),
            triggerTile('Sosyal ortamda', 'social'),
            triggerTile('Alkol kullanırken', 'alcohol'),
            const SizedBox(height: 20),
            sectionTitle('Stres Seviyesi'),
            DropdownButtonFormField<String>(
              initialValue: stressLevel,
              decoration: const InputDecoration(
                labelText: 'Stres seviyesi',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Düşük', child: Text('Düşük')),
                DropdownMenuItem(value: 'Orta', child: Text('Orta')),
                DropdownMenuItem(value: 'Yüksek', child: Text('Yüksek')),
              ],
              onChanged: (value) {
                setState(() {
                  stressLevel = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            sectionTitle('Bırakma Sebebi'),
            DropdownButtonFormField<String>(
              initialValue: quitReason,
              decoration: const InputDecoration(
                labelText: 'Bırakma sebebi',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Sağlık', child: Text('Sağlık')),
                DropdownMenuItem(value: 'Aile', child: Text('Aile')),
                DropdownMenuItem(value: 'Maddi sebepler', child: Text('Maddi sebepler')),
                DropdownMenuItem(value: 'Çocuklar', child: Text('Çocuklar')),
                DropdownMenuItem(value: 'Performans', child: Text('Performans')),
              ],
              onChanged: (value) {
                setState(() {
                  quitReason = value!;
                });
              },
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BreathTestPage(),
                    ),
                  );
                },
                child: const Text(
                  'Devam Et',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
