import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../models/daily_log.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';

enum _DateRange { thisWeek, thisMonth, custom }

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  _DateRange _range = _DateRange.thisWeek;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _exporting = false;

  DateTime get _startDate {
    switch (_range) {
      case _DateRange.thisWeek:
        final now = DateTime.now();
        return now.subtract(Duration(days: now.weekday - 1));
      case _DateRange.thisMonth:
        final now = DateTime.now();
        return DateTime(now.year, now.month, 1);
      case _DateRange.custom:
        return _customStart ?? DateTime.now().subtract(const Duration(days: 7));
    }
  }

  DateTime get _endDate => _customEnd ?? DateTime.now();

  int get _dayCount => _endDate.difference(_startDate).inDays + 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapor Al'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRangeCard(context),
            const SizedBox(height: 16),
            _buildExportCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tarih Aralığı',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<_DateRange>(
              segments: const [
                ButtonSegment(
                    value: _DateRange.thisWeek, label: Text('Bu Hafta')),
                ButtonSegment(
                    value: _DateRange.thisMonth, label: Text('Bu Ay')),
                ButtonSegment(
                    value: _DateRange.custom, label: Text('Özel')),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
            if (_range == _DateRange.custom) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_customStart != null
                          ? '${_customStart!.day}.${_customStart!.month}.${_customStart!.year}'
                          : 'Başlangıç'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _customStart ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _customStart = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_customEnd != null
                          ? '${_customEnd!.day}.${_customEnd!.month}.${_customEnd!.year}'
                          : 'Bitiş'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _customEnd ?? DateTime.now(),
                          firstDate: _customStart ?? DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _customEnd = d);
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Seçili aralık: $_dayCount gün',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dışa Aktar',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ExportOptionTile(
              icon: Icons.picture_as_pdf_outlined,
              title: 'PDF Raporu',
              subtitle:
                  'Profil bilgileri, öğün listesi ve günlük özet',
              color: Colors.red.shade400,
              loading: _exporting,
              onTap: () => _exportPdf(context),
            ),
            const Divider(height: 24),
            _ExportOptionTile(
              icon: Icons.table_chart_outlined,
              title: 'Excel Tablosu',
              subtitle: 'Tüm yemek kayıtları ve günlük toplamlar',
              color: Colors.green.shade600,
              loading: _exporting,
              onTap: () => _exportExcel(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<DailyLog>> _fetchLogs(BuildContext context) async {
    final profileId = context.read<ProfileProvider>().activeProfileId;
    final allLogs = await NutritionProvider.loadLogsForProfile(
      profileId,
      days: _dayCount + 1,
    );

    return allLogs.where((log) {
      final date = DateTime(log.date.year, log.date.month, log.date.day);
      final start =
          DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  Future<Directory> _resolveDir() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
      return await getApplicationDocumentsDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _exportPdf(BuildContext context) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final profile = context.read<ProfileProvider>().activeProfile;
      if (profile == null) {
        _showSnack(context, 'Önce bir profil oluşturun.');
        return;
      }

      final logs = await _fetchLogs(context);
      final pdf = pw.Document();

      // Page 1: Profile info
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('NutriLens Beslenme Raporu',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                  'Tarih: ${_startDate.day}.${_startDate.month}.${_startDate.year} - ${_endDate.day}.${_endDate.month}.${_endDate.year}'),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Profil Bilgileri',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('İsim: ${profile.name}'),
              pw.Text('Yaş: ${profile.age}  Boy: ${profile.height.toStringAsFixed(0)}cm  Kilo: ${profile.weight.toStringAsFixed(1)}kg'),
              pw.Text('Hedef: ${profile.goalLabel}  Aktivite: ${profile.activityLabel}'),
              pw.SizedBox(height: 12),
              pw.Text('Günlük Makro Hedefleri',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text(
                  'Kalori: ${profile.calorieGoal.toStringAsFixed(0)} kcal  |  Protein: ${profile.proteinGoal.toStringAsFixed(0)}g  |  Karbonhidrat: ${profile.carbGoal.toStringAsFixed(0)}g  |  Yağ: ${profile.fatGoal.toStringAsFixed(0)}g'),
              pw.SizedBox(height: 6),
              pw.Text('BMR: ${profile.bmr.toStringAsFixed(0)} kcal/gün  |  TDEE: ${profile.tdee.toStringAsFixed(0)} kcal/gün'),
              pw.Divider(),
              pw.SizedBox(height: 8),
              // Weekly calorie table
              pw.Text('Günlük Kalori Özeti',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.green100),
                    children: [
                      _pdfCell('Tarih', bold: true),
                      _pdfCell('Kalori', bold: true),
                      _pdfCell('Protein', bold: true),
                      _pdfCell('Karbonhidrat', bold: true),
                      _pdfCell('Yağ', bold: true),
                    ],
                  ),
                  ...logs.map((log) {
                    final n = log.totalNutrition;
                    return pw.TableRow(children: [
                      _pdfCell(
                          '${log.date.day}.${log.date.month}.${log.date.year}'),
                      _pdfCell('${n.calories.toStringAsFixed(0)} kcal'),
                      _pdfCell('${n.protein.toStringAsFixed(1)}g'),
                      _pdfCell('${n.carbohydrates.toStringAsFixed(1)}g'),
                      _pdfCell('${n.fat.toStringAsFixed(1)}g'),
                    ]);
                  }),
                ],
              ),
            ],
          ),
        ),
      );

      // Page 2+: Daily food entries
      for (final log in logs) {
        if (log.entries.isEmpty) continue;
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    '${log.date.day}.${log.date.month}.${log.date.year} Öğünleri',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.green50),
                      children: [
                        _pdfCell('Öğün', bold: true),
                        _pdfCell('Yemek', bold: true),
                        _pdfCell('Porsiyon', bold: true),
                        _pdfCell('Kalori', bold: true),
                        _pdfCell('P/K/Y', bold: true),
                      ],
                    ),
                    ...log.entries.map((e) {
                      final n = e.nutritionData;
                      final factor = e.portionSize / 100;
                      return pw.TableRow(children: [
                        _pdfCell(e.mealType),
                        _pdfCell(e.name),
                        _pdfCell(
                            '${e.portionSize.toStringAsFixed(0)} ${e.portionUnit}'),
                        _pdfCell(
                            '${(n.calories * factor).toStringAsFixed(0)} kcal'),
                        _pdfCell(
                            '${(n.protein * factor).toStringAsFixed(0)}/${(n.carbohydrates * factor).toStringAsFixed(0)}/${(n.fat * factor).toStringAsFixed(0)}g'),
                      ]);
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      }

      final bytes = await pdf.save();
      final dir = await _resolveDir();
      final fileName =
          'nutrilens_rapor_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        _showSnack(context, 'PDF kaydedildi: ${file.path}',
            isSuccess: true);
      }
    } catch (e) {
      if (mounted) _showSnack(context, 'PDF oluşturma hatası: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final profile = context.read<ProfileProvider>().activeProfile;
      if (profile == null) {
        _showSnack(context, 'Önce bir profil oluşturun.');
        return;
      }

      final logs = await _fetchLogs(context);
      final excel = Excel.createExcel();

      // Sheet 1: Food entries
      final sheet = excel['Kayıtlar'];
      final headers = [
        'Tarih', 'Öğün', 'Yemek Adı', 'Porsiyon', 'Birim',
        'Kalori (kcal)', 'Protein (g)', 'Karbonhidrat (g)', 'Yağ (g)'
      ];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true);
      }

      int row = 1;
      for (final log in logs) {
        for (final entry in log.entries) {
          final factor = entry.portionSize / 100;
          final n = entry.nutritionData;
          final rowData = [
            '${log.date.day}.${log.date.month}.${log.date.year}',
            entry.mealType,
            entry.name,
            entry.portionSize.toStringAsFixed(0),
            entry.portionUnit,
            (n.calories * factor).toStringAsFixed(1),
            (n.protein * factor).toStringAsFixed(1),
            (n.carbohydrates * factor).toStringAsFixed(1),
            (n.fat * factor).toStringAsFixed(1),
          ];
          for (var c = 0; c < rowData.length; c++) {
            sheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: c, rowIndex: row))
                .value = TextCellValue(rowData[c]);
          }
          row++;
        }
      }

      // Sheet 2: Daily summary
      final summarySheet = excel['Özet'];
      final summaryHeaders = [
        'Tarih', 'Toplam Kalori', 'Protein (g)', 'Karbonhidrat (g)', 'Yağ (g)', 'Su (ml)'
      ];
      for (var i = 0; i < summaryHeaders.length; i++) {
        final cell = summarySheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(summaryHeaders[i]);
        cell.cellStyle = CellStyle(bold: true);
      }
      for (var r = 0; r < logs.length; r++) {
        final log = logs[r];
        final n = log.totalNutrition;
        final summaryRow = [
          '${log.date.day}.${log.date.month}.${log.date.year}',
          n.calories.toStringAsFixed(1),
          n.protein.toStringAsFixed(1),
          n.carbohydrates.toStringAsFixed(1),
          n.fat.toStringAsFixed(1),
          log.waterIntakeMl.toStringAsFixed(0),
        ];
        for (var c = 0; c < summaryRow.length; c++) {
          summarySheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: c, rowIndex: r + 1))
              .value = TextCellValue(summaryRow[c]);
        }
      }

      // Remove default empty sheet
      excel.delete('Sheet1');

      final bytes = excel.save();
      if (bytes == null) throw Exception('Excel kaydedilemedi');

      final dir = await _resolveDir();
      final fileName =
          'nutrilens_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        _showSnack(context, 'Excel kaydedildi: ${file.path}',
            isSuccess: true);
      }
    } catch (e) {
      if (mounted) _showSnack(context, 'Excel oluşturma hatası: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSnack(BuildContext context, String message,
      {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isSuccess ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  const _ExportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: Theme.of(context).textTheme.bodySmall),
      trailing: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.download_outlined,
              color: Theme.of(context).colorScheme.primary),
      onTap: loading ? null : onTap,
    );
  }
}
