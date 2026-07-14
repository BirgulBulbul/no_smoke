import 'package:flutter/material.dart';

import '../core/app_texts.dart';

class ConsecutiveSmokingSection extends StatelessWidget {
  final String consecutiveSmokingHabit;
  final ValueChanged<String> onHabitChanged;
  final String? consecutiveSmokingCount;
  final ValueChanged<String> onCountChanged;

  const ConsecutiveSmokingSection({
    super.key,
    required this.consecutiveSmokingHabit,
    required this.onHabitChanged,
    required this.consecutiveSmokingCount,
    required this.onCountChanged,
  });

  static const List<String> habitOptions = [
    'Hayır',
    'Evet, bazen',
    'Evet, sık sık',
  ];

  static const List<String> countOptions = [
    '2 adet',
    '3 adet',
    '4 adet',
    '5+ adet',
  ];

  bool get _needsCount => consecutiveSmokingHabit != 'Hayır';

  @override
  Widget build(BuildContext context) {
    String labelForHabit(String value) {
      switch (value) {
        case 'Hayır':
          return context.t('no');
        case 'Evet, bazen':
          return context.t('yesSometimes');
        case 'Evet, sık sık':
          return context.t('yesOften');
        default:
          return value;
      }
    }

    String labelForCount(String value) {
      switch (value) {
        case '2 adet':
          return context.t('twoCig');
        case '3 adet':
          return context.t('threeCig');
        case '4 adet':
          return context.t('fourCig');
        case '5+ adet':
          return context.t('fivePlusCig');
        default:
          return value;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          context.t('chainSmokingSituation'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: consecutiveSmokingHabit,
          decoration: InputDecoration(
            labelText: context.t('chainSmokingAsk'),
            border: OutlineInputBorder(),
          ),
          items: habitOptions
              .map((value) => DropdownMenuItem<String>(value: value, child: Text(labelForHabit(value))))
              .toList(),
          onChanged: (value) => onHabitChanged(value ?? 'Hayır'),
        ),
        if (_needsCount) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: consecutiveSmokingCount,
            decoration: InputDecoration(
              labelText: context.t('chainSmokingCountAsk'),
              border: OutlineInputBorder(),
            ),
            items: countOptions
                .map((value) => DropdownMenuItem<String>(value: value, child: Text(labelForCount(value))))
                .toList(),
            onChanged: (value) => onCountChanged(value ?? '2 adet'),
          ),
        ],
      ],
    );
  }
}
