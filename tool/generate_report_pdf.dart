import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final input = File('docs/no_smoke_teknik_rapor.md');
  final output = File('docs/no_smoke_teknik_rapor.pdf');

  if (!input.existsSync()) {
    stderr.writeln('Input file not found: ${input.path}');
    exit(1);
  }

  final content = input.readAsStringSync();
  final lines = content.split('\n');

  final document = pw.Document();

  final widgets = <pw.Widget>[];
  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    if (line.isEmpty) {
      widgets.add(pw.SizedBox(height: 6));
      continue;
    }

    if (line.startsWith('# ')) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
          child: pw.Text(
            line.substring(2),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
      continue;
    }

    if (line.startsWith('## ')) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(
            line.substring(3),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
      continue;
    }

    if (line.startsWith('### ')) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
          child: pw.Text(
            line.substring(4),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
      continue;
    }

    widgets.add(
      pw.Text(
        line,
        style: const pw.TextStyle(fontSize: 10.5),
      ),
    );
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => widgets,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sayfa ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
    ),
  );

  output.writeAsBytesSync(await document.save());
  stdout.writeln('PDF created: ${output.path}');
}
