import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/equipment.dart';

// إحصائيات جهاز واحد لفترة معينة - بتتحسب من سجل القرايات (DeviceLogEntry)
// اللي بييجي من نفس الـ API اللي بيستخدمه الداشبورد نفسه
class DeviceReportStat {
  final Equipment device;
  final List<DeviceLogEntry> logs;

  DeviceReportStat({required this.device, required this.logs});

  double get latestFlow => logs.isNotEmpty ? logs.last.flow : 0;
  double get latestTotal => logs.isNotEmpty ? logs.last.totalizer : 0;

  double get avgFlow => logs.isEmpty
      ? 0
      : logs.map((l) => l.flow).reduce((a, b) => a + b) / logs.length;

  double get maxFlow =>
      logs.isEmpty ? 0 : logs.map((l) => l.flow).reduce((a, b) => a > b ? a : b);

  // استهلاك الفترة = فرق التوتاليزر من أول قراية لآخر قراية في المدى المحدد
  double get usageInPeriod =>
      logs.length < 2 ? 0 : (logs.last.totalizer - logs.first.totalizer).abs();

  // بيقسم اللوجز لعدد "buckets" ويحسب متوسط الفلو في كل واحد - ده اللي بيرسم
  // بيه السباركلاين الصغيرة تحت كل عداد في التقرير
  List<double> buckets(int count) {
    if (logs.isEmpty) return List.filled(count, 0);
    final result = <double>[];
    final chunk = (logs.length / count).ceil().clamp(1, logs.length);
    for (var i = 0; i < logs.length; i += chunk) {
      final end = (i + chunk).clamp(0, logs.length);
      final slice = logs.sublist(i, end);
      final avg = slice.map((l) => l.flow).reduce((a, b) => a + b) / slice.length;
      result.add(avg);
      if (result.length >= count) break;
    }
    while (result.length < count) {
      result.add(result.isNotEmpty ? result.last : 0);
    }
    return result;
  }
}

final _pdfPrimary = PdfColor.fromInt(0xFF3F74CB);
final _pdfDark = PdfColor.fromInt(0xFF0F1B2D);
final _pdfGrey = PdfColor.fromInt(0xFF60728C);
final _pdfGreen = PdfColor.fromInt(0xFF1FAE7E);
final _pdfRed = PdfColor.fromInt(0xFFFF5470);
final _pdfBorder = PdfColor.fromInt(0xFFDDE5F0);
final _pdfPanel = PdfColor.fromInt(0xFFF3F6FB);

// بيبني تقرير PDF كامل عن حالة الأجهزة والترندات - نفس فكرة الداشبورد بس كملف
// تقدري تنزليه أو تشاركيه، مش لازم تفتحي التطبيق عشان تشوفيه
Future<Uint8List> buildDashboardReportPdf({
  required List<DeviceReportStat> stats,
  required String rangeLabel,
  required int onlineCount,
  required int totalCount,
}) async {
  final doc = pw.Document();

  // لوجو الشركة - بيتحمّل مرة واحدة هنا وبيتحط في رأس كل صفحة من التقرير
  final logoBytes = await rootBundle.load('assets/images/atom_logo.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

  final now = DateTime.now();
  final generatedAt =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // لوجو الشركة الرسمي (نفس اللوجو المستخدم في التطبيق) بدل
                  // ما كان اسم الشركة نص عادي بس
                  pw.Image(logoImage, height: 32),
                  pw.SizedBox(height: 4),
                  pw.Text('Dashboard Report',
                      style: pw.TextStyle(fontSize: 11, color: _pdfGrey)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Range: $rangeLabel',
                      style: pw.TextStyle(fontSize: 10, color: _pdfDark)),
                  pw.Text('Generated: $generatedAt',
                      style: pw.TextStyle(fontSize: 9, color: _pdfGrey)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: _pdfBorder, thickness: 1),
        ],
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: _pdfGrey),
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 6),
        _systemStatusBanner(onlineCount, totalCount),
        pw.SizedBox(height: 20),
        pw.Text(
          'Meters',
          style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold, color: _pdfDark),
        ),
        pw.SizedBox(height: 8),
        if (stats.isEmpty)
          pw.Text('No meters with recorded readings in this range.',
              style: pw.TextStyle(fontSize: 10, color: _pdfGrey))
        else
          ...stats.map(_meterCard),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _systemStatusBanner(int onlineCount, int totalCount) {
  final offlineCount = totalCount - onlineCount;
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _pdfPanel,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: _pdfBorder),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('System Status',
                style: pw.TextStyle(fontSize: 10, color: _pdfGrey)),
            pw.SizedBox(height: 3),
            pw.Text(
              '$onlineCount of $totalCount devices online',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold, color: _pdfDark),
            ),
          ],
        ),
        pw.Row(
          children: [
            _statusChip('$onlineCount online', _pdfGreen),
            pw.SizedBox(width: 8),
            _statusChip('$offlineCount offline', _pdfRed),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _statusChip(String label, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(
      color: PdfColor(color.red, color.green, color.blue, 0.12),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(
      label,
      style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _meterCard(DeviceReportStat s) {
  final bars = s.buckets(10);
  final maxBar = bars.isEmpty
      ? 1.0
      : bars.reduce((a, b) => a > b ? a : b).clamp(0.0001, double.infinity);

  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _pdfBorder),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              s.device.name,
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold, color: _pdfDark),
            ),
            pw.Text(
              s.device.online ? 'Online' : 'Offline',
              style: pw.TextStyle(
                fontSize: 9,
                color: s.device.online ? _pdfGreen : _pdfRed,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _statCol('Flow', '${s.latestFlow.toStringAsFixed(2)} m3/h', _pdfPrimary),
            _statCol('Avg Flow', '${s.avgFlow.toStringAsFixed(2)} m3/h', _pdfDark),
            _statCol('Max Flow', '${s.maxFlow.toStringAsFixed(2)} m3/h', _pdfDark),
            _statCol('Usage', '${s.usageInPeriod.toStringAsFixed(2)} m3', _pdfDark),
            _statCol('Total', '${s.latestTotal.toStringAsFixed(2)} m3', _pdfDark),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.SizedBox(
          height: 30,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: bars.map((v) {
              final h = (v / maxBar) * 28;
              return pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 1.5),
                  height: h < 2 ? 2 : h,
                  decoration: pw.BoxDecoration(
                    color: _pdfPrimary,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _statCol(String label, String value, PdfColor color) {
  return pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _pdfGrey)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    ),
  );
}
