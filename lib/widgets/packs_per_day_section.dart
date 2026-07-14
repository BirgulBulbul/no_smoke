import 'package:flutter/material.dart';

import '../core/app_texts.dart';

class PacksPerDaySection extends StatelessWidget {
  final String selectedPackOption;
  final String? selectedHighPackOption;
  final ValueChanged<String> onPackOptionChanged;
  final ValueChanged<String> onHighPackOptionChanged;

  const PacksPerDaySection({
    super.key,
    required this.selectedPackOption,
    required this.selectedHighPackOption,
    required this.onPackOptionChanged,
    required this.onHighPackOptionChanged,
  });

  static const List<String> packOptions = [
    '1 paketten az',
    '1 paket',
    '2 paket',
    '3 paket',
    '3+ paket',
  ];

  static const List<String> highPackOptions = [
    '4 paket',
    '5 paket',
    '6 paket',
    '7+ paket',
  ];

  bool get _needsHighPackQuestion => selectedPackOption == '3+ paket';

  @override
  Widget build(BuildContext context) {
    String labelForPack(String value) {
      switch (value) {
        case '1 paketten az':
          return context.t('lessThanOnePack');
        case '1 paket':
          return context.t('onePack');
        case '2 paket':
          return context.t('twoPack');
        case '3 paket':
          return context.t('threePack');
        case '3+ paket':
          return context.t('threePlusPack');
        case '4 paket':
          return context.t('fourPack');
        case '5 paket':
          return context.t('fivePack');
        case '6 paket':
          return context.t('sixPack');
        case '7+ paket':
          return context.t('sevenPlusPack');
        default:
          return value;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedPackOption,
          decoration: InputDecoration(
            labelText: context.t('packsPerDayQuestion'),
            border: OutlineInputBorder(),
          ),
          items: packOptions
              .map((value) => DropdownMenuItem<String>(value: value, child: Text(labelForPack(value))))
              .toList(),
          onChanged: (value) => onPackOptionChanged(value ?? '1 paketten az'),
        ),
        if (_needsHighPackQuestion) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedHighPackOption,
            decoration: InputDecoration(
              labelText: context.t('packsApproxQuestion'),
              border: OutlineInputBorder(),
            ),
            items: highPackOptions
                .map((value) => DropdownMenuItem<String>(value: value, child: Text(labelForPack(value))))
                .toList(),
            onChanged: (value) => onHighPackOptionChanged(value ?? '4 paket'),
          ),
        ],
      ],
    );
  }
}