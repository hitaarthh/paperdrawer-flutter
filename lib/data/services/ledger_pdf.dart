import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../domain/formats.dart';
import '../../domain/models/ledger.dart';
import 'drawer_actions.dart';

Future<XFile> buildLedgerPdf({
  required String title,
  required DateTime opened,
  required DateTime? settled,
  required List<LedgerEntry> entries,
  required List<String> files,
  String serial = '',
}) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter.ttf'));
  final document = pw.Document(title: title, author: 'PaperDrawer');
  final titleStyle = pw.TextStyle(font: font, fontSize: 25);
  final labelStyle = pw.TextStyle(
    font: font,
    fontSize: 10,
    color: PdfColors.grey700,
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: entries.length + files.length + 5,
      theme: pw.ThemeData.withFont(base: font),
      header: (_) => pw.Text('PAPERDRAWER · CLAIM LEDGER', style: labelStyle),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: labelStyle,
        ),
      ),
      build: (_) => [
        pw.SizedBox(height: 16),
        pw.Text(title, style: titleStyle),
        pw.Text(
          'Opened ${longDate(opened)} · ${settled == null ? 'Open' : 'Settled ${longDate(settled)}'}',
        ),
        pw.SizedBox(height: 16),
        for (final entry in entries) ...[
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            '${longDate(entry.date)} · ${entry.kind.label.toUpperCase()}',
            style: labelStyle,
          ),
          pw.Text(entry.text, overflow: pw.TextOverflow.span),
          if (entry.details.isNotEmpty)
            pw.Text(entry.details, overflow: pw.TextOverflow.span),
          if (entry.reference.isNotEmpty)
            pw.Text('Reference ${entry.reference}', style: labelStyle),
          pw.SizedBox(height: 6),
        ],
        if (files.isNotEmpty || serial.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('ON FILE', style: labelStyle),
          if (serial.isNotEmpty) pw.Text('Serial number $serial'),
          for (final file in files)
            pw.Text(file, overflow: pw.TextOverflow.span),
        ],
      ],
    ),
  );
  final safeTitle = String.fromCharCodes(
    title.replaceAll(RegExp(r'[\\/:\x00-\x1f]'), '-').runes.take(56),
  );
  return NamedShareData(
    await document.save(),
    name: '$safeTitle-ledger.pdf',
    mimeType: 'application/pdf',
  );
}
