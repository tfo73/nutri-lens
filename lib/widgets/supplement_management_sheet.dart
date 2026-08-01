import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/supplement_model.dart';
import '../providers/language_provider.dart';
import '../services/notification_service.dart';
import 'package:provider/provider.dart';

class SupplementManagementSheet extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback? onDataChanged;

  const SupplementManagementSheet({
    super.key,
    required this.selectedDate,
    this.onDataChanged,
  });

  static Future<void> show(BuildContext context, {required DateTime selectedDate, VoidCallback? onDataChanged}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => SupplementManagementSheet(
        selectedDate: selectedDate,
        onDataChanged: onDataChanged,
      ),
    );
  }

  static Future<Map<String, double>> getSupplementMicroAdditions(DateTime selectedDate) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final jsonStr = prefs.getString('user_supplements_v2');
    if (jsonStr == null || jsonStr.isEmpty) return {};

    final list = SupplementItem.decodeList(jsonStr);
    final additions = <String, double>{};

    for (final item in list) {
      final takenDoses = prefs.getInt('supp_dose_${dateKey}_${item.id}') ?? 0;
      if (takenDoses > 0 && item.microNutrientKey != null && item.microAmount != null && item.microAmount! > 0) {
        final key = item.microNutrientKey!;
        final amount = takenDoses * item.microAmount!;
        additions[key] = (additions[key] ?? 0.0) + amount;
      }
    }
    return additions;
  }

  @override
  State<SupplementManagementSheet> createState() => _SupplementManagementSheetState();
}

class _SupplementManagementSheetState extends State<SupplementManagementSheet> {
  List<SupplementItem> _supplements = [];
  Map<String, int> _todayDosesMap = {};
  bool _showAddForm = false;
  bool _isLoading = true;

  // Form State
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  int _timesPerDay = 1;
  String? _imagePath;
  String _selectedMicroKey = 'D-Vit';
  String _selectedUnit = 'mcg';
  List<TimeOfDay> _customDoseTimes = [const TimeOfDay(hour: 8, minute: 0)];

  static const List<(String key, String displayName, String unit, String category)> _allMicroOptions = [
    // Vitaminler
    ('D-Vit', 'D Vitamini', 'mcg', 'Vitaminler'),
    ('C-Vit', 'C Vitamini', 'mg', 'Vitaminler'),
    ('B12', 'B12 Vitamini', 'mcg', 'Vitaminler'),
    ('A-Vit', 'A Vitamini', 'mcg', 'Vitaminler'),
    ('E-Vit', 'E Vitamini', 'mg', 'Vitaminler'),
    ('K-Vit', 'K Vitamini', 'mcg', 'Vitaminler'),
    ('B1', 'B1 Vitamini (Tiamin)', 'mg', 'Vitaminler'),
    ('B2', 'B2 Vitamini (Riboflavin)', 'mg', 'Vitaminler'),
    ('B3', 'B3 Vitamini (Niasin)', 'mg', 'Vitaminler'),
    ('B5', 'B5 Vitamini (Pantotenik Asit)', 'mg', 'Vitaminler'),
    ('B6', 'B6 Vitamini (Piridoksin)', 'mg', 'Vitaminler'),
    ('B7', 'B7 Vitamini (Biotin)', 'mcg', 'Vitaminler'),
    ('B9', 'B9 Vitamini (Folik Asit)', 'mcg', 'Vitaminler'),
    // Mineraller
    ('Demir', 'Demir', 'mg', 'Mineraller'),
    ('Magnezyum', 'Magnezyum', 'mg', 'Mineraller'),
    ('Kalsiyum', 'Kalsiyum', 'mg', 'Mineraller'),
    ('Potasyum', 'Potasyum', 'mg', 'Mineraller'),
    ('Sodyum', 'Sodyum', 'mg', 'Mineraller'),
    ('Çinko', 'Çinko', 'mg', 'Mineraller'),
    ('Fosfor', 'Fosfor', 'mg', 'Mineraller'),
    ('Bakır', 'Bakır', 'mg', 'Mineraller'),
    ('Manganez', 'Manganez', 'mg', 'Mineraller'),
    ('Selenyum', 'Selenyum', 'mcg', 'Mineraller'),
    ('İyot', 'İyot', 'mcg', 'Mineraller'),
    ('Krom', 'Krom', 'mcg', 'Mineraller'),
    ('Molibden', 'Molibden', 'mcg', 'Mineraller'),
    // Yağ Asitleri & Özel
    ('Omega-3', 'Omega-3', 'g', 'Yağ Asitleri'),
    ('Omega-6', 'Omega-6', 'g', 'Yağ Asitleri'),
    ('EPA', 'EPA (Omega-3)', 'mg', 'Yağ Asitleri'),
    ('DHA', 'DHA (Omega-3)', 'mg', 'Yağ Asitleri'),
    ('ALA', 'ALA (Omega-3)', 'mg', 'Yağ Asitleri'),
    // Amino Asitler & Takviyeler
    ('Lif', 'Diyet Lifi', 'g', 'Amino Asit & Lif'),
    ('Kolajen', 'Kolajen', 'g', 'Amino Asit & Lif'),
    ('Kreatin', 'Kreatin', 'g', 'Amino Asit & Lif'),
    ('Glutamin', 'L-Glutamin', 'g', 'Amino Asit & Lif'),
    ('Lösin', 'Lösin', 'g', 'Amino Asit & Lif'),
    ('İzolösin', 'İzolösin', 'g', 'Amino Asit & Lif'),
    ('Valin', 'Valin', 'g', 'Amino Asit & Lif'),
    ('Lizin', 'Lizin', 'g', 'Amino Asit & Lif'),
    ('Metiyonin', 'Metiyonin', 'mg', 'Amino Asit & Lif'),
    ('Kolin', 'Kolin', 'mg', 'Amino Asit & Lif'),
    ('CoQ10', 'Koenzim Q10', 'mg', 'Diğer Takviyeler'),
    ('Ashwagandha', 'Ashwagandha', 'mg', 'Diğer Takviyeler'),
    ('Multivitamin', 'Multivitamin Kompleks', 'mg', 'Diğer Takviyeler'),
  ];

  @override
  void initState() {
    super.initState();
    _updateDoseTimeSlots(_timesPerDay);
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(widget.selectedDate);

  void _updateDoseTimeSlots(int times) {
    _timesPerDay = times;
    if (times == 1) {
      _customDoseTimes = [const TimeOfDay(hour: 8, minute: 0)];
    } else if (times == 2) {
      _customDoseTimes = [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 20, minute: 0)];
    } else if (times == 3) {
      _customDoseTimes = [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 14, minute: 0), const TimeOfDay(hour: 20, minute: 0)];
    } else if (times == 4) {
      _customDoseTimes = [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 12, minute: 0), const TimeOfDay(hour: 16, minute: 0), const TimeOfDay(hour: 20, minute: 0)];
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file != null) {
      setState(() {
        _imagePath = file.path;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    final jsonStr = prefs.getString('user_supplements_v2');
    List<SupplementItem> list = jsonStr != null ? SupplementItem.decodeList(jsonStr) : [];

    // Sync onboarding choices if list is empty
    if (list.isEmpty) {
      List<String> onboardingSupps = [];
      final answersStr = prefs.getString('onboarding_answers');
      if (answersStr != null) {
        try {
          final answers = jsonDecode(answersStr);
          final suppList = answers['supplements'] as List?;
          if (suppList != null) onboardingSupps = suppList.cast<String>().toList();
          final other = answers['supplementsOther'] as String?;
          if (other != null && other.trim().isNotEmpty) onboardingSupps.add(other.trim());
        } catch (_) {}
      }

      if (onboardingSupps.isNotEmpty) {
        list = onboardingSupps.map((suppName) {
          final sName = suppName.trim();
          String microKey = 'D-Vit';
          String unit = 'mcg';
          double amount = 25.0;

          final sLower = sName.toLowerCase();
          if (sLower.contains('omega')) {
            microKey = 'Omega-3';
            unit = 'g';
            amount = 1.0;
          } else if (sLower.contains('b12')) {
            microKey = 'B12';
            unit = 'mcg';
            amount = 2.4;
          } else if (sLower.contains('magnezyum') || sLower.contains('mg')) {
            microKey = 'Magnezyum';
            unit = 'mg';
            amount = 200.0;
          } else if (sLower.contains('c vit') || sLower.contains('c-vit')) {
            microKey = 'C-Vit';
            unit = 'mg';
            amount = 500.0;
          } else if (sLower.contains('demir') || sLower.contains('iron')) {
            microKey = 'Demir';
            unit = 'mg';
            amount = 18.0;
          } else if (sLower.contains('kalsiyum')) {
            microKey = 'Kalsiyum';
            unit = 'mg';
            amount = 500.0;
          }

          return SupplementItem(
            id: DateTime.now().microsecondsSinceEpoch.toString() + '_' + sName.hashCode.toString(),
            name: sName,
            timesPerDay: 1,
            reminderTime: '08:00',
            doseTimes: ['08:00'],
            microNutrientKey: microKey,
            microAmount: amount,
            microUnit: unit,
          );
        }).toList();

        await prefs.setString('user_supplements_v2', SupplementItem.encodeList(list));
      }
    }

    Map<String, int> dosesMap = {};
    for (final item in list) {
      final savedDose = prefs.getInt('supp_dose_${_dateKey}_${item.id}') ?? 0;
      dosesMap[item.id] = savedDose;
    }

    if (mounted) {
      setState(() {
        _supplements = list;
        _todayDosesMap = dosesMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSupplements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_supplements_v2', SupplementItem.encodeList(_supplements));

    // Schedule Notifications for each supplement and dose
    for (final item in _supplements) {
      await NotificationService.cancelSupplementNotifications(item.id);
      final doseTimes = item.getCalculatedDoseTimes();
      final baseId = item.id.hashCode.abs() % 100000;
      for (int i = 0; i < doseTimes.length; i++) {
        final parts = doseTimes[i].split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]) ?? 8;
          final m = int.tryParse(parts[1]) ?? 0;
          await NotificationService.scheduleSupplementDoseNotification(
            id: 900000 + baseId + i,
            supplementName: item.name,
            hour: h,
            minute: m,
          );
        }
      }
    }

    widget.onDataChanged?.call();
  }

  Future<void> _updateDose(String suppId, int count) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _todayDosesMap[suppId] = count;
    });
    await prefs.setInt('supp_dose_${_dateKey}_$suppId', count);
    widget.onDataChanged?.call();
  }

  void _handleAddFormSubmit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final isDuplicate = _supplements.any((s) => s.name.trim().toLowerCase() == name.toLowerCase());
    if (isDuplicate) {
      final isTr = Provider.of<LanguageProvider>(context, listen: false).isTurkish;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTr ? 'Bu isimde bir takviye zaten ekli!' : 'A supplement with this name already exists!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    final doseTimeStrs = _customDoseTimes
        .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .toList();

    final newItem = SupplementItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      timesPerDay: _timesPerDay,
      reminderTime: doseTimeStrs.isNotEmpty ? doseTimeStrs.first : '08:00',
      doseTimes: doseTimeStrs,
      microNutrientKey: _selectedMicroKey,
      microAmount: amount,
      microUnit: _selectedUnit,
      imagePath: _imagePath,
    );

    setState(() {
      _supplements.add(newItem);
      _nameCtrl.clear();
      _amountCtrl.clear();
      _imagePath = null;
      _showAddForm = false;
    });

    await _saveSupplements();
  }

  void _openEditSheet(SupplementItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditSupplementSheet(
        item: item,
        existingSupplements: _supplements,
        allMicroOptions: _allMicroOptions,
        onSave: (updatedItem) async {
          setState(() {
            final idx = _supplements.indexWhere((s) => s.id == updatedItem.id);
            if (idx != -1) _supplements[idx] = updatedItem;
          });
          await _saveSupplements();
        },
        onDelete: (id) async {
          await NotificationService.cancelSupplementNotifications(id);
          setState(() {
            _supplements.removeWhere((s) => s.id == id);
            _todayDosesMap.remove(id);
          });
          await _saveSupplements();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTr = context.watch<LanguageProvider>().isTurkish;

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final innerBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF8E8E93);
    final accentColor = const Color(0xFFD97706);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark ? const Color(0xFF121212).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.96),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // Top Drag Handle & Apple Header Bar
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 36,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title Bar with Add (+) Toggle Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isTr ? 'Takviye Yönetimi' : 'Supplements Management',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _showAddForm = !_showAddForm),
                              style: IconButton.styleFrom(
                                backgroundColor: _showAddForm
                                    ? accentColor.withValues(alpha: 0.2)
                                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              ),
                              icon: Icon(
                                _showAddForm ? Icons.close_rounded : Icons.add_rounded,
                                color: accentColor,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Add Supplement Form Section (Expandable)
                  if (_showAddForm)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isTr ? 'YENİ TAKVİYE EKLE' : 'ADD NEW SUPPLEMENT',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                // Image Picker Button / Thumbnail
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: _imagePath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(
                                            File(_imagePath!),
                                            width: 38,
                                            height: 38,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: innerBg,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.add_a_photo_rounded, size: 14, color: accentColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                isTr ? 'Görsel' : 'Photo',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Takviye İsmi
                            TextField(
                              controller: _nameCtrl,
                              decoration: InputDecoration(
                                labelText: isTr ? 'Takviye İsmi' : 'Supplement Name',
                                filled: true,
                                fillColor: innerBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Günde Kaç Kere Alınacak
                            Text(
                              isTr ? 'Günde Kaç Kere Alınacak?' : 'Times Per Day?',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: CupertinoSegmentedControl<int>(
                                selectedColor: accentColor,
                                borderColor: accentColor,
                                groupValue: _timesPerDay,
                                children: const {
                                  1: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('1 Defa')),
                                  2: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('2 Defa')),
                                  3: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('3 Defa')),
                                  4: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('4 Defa')),
                                },
                                onValueChanged: (val) => setState(() => _updateDoseTimeSlots(val)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Saat Seçimleri (Yan Yana Kaydırılabilir Doz Saatleri)
                            Text(
                              isTr ? 'Doz Saatleri' : 'Dose Times',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: List.generate(_timesPerDay, (i) {
                                  final time = _customDoseTimes[i];
                                  final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final t = await showTimePicker(
                                          context: context,
                                          initialTime: time,
                                        );
                                        if (t != null) {
                                          setState(() {
                                            _customDoseTimes[i] = t;
                                          });
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                                      ),
                                      icon: const Icon(Icons.access_time_rounded, size: 14),
                                      label: Text(
                                        '${i + 1}. Doz: $timeStr',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // İlişkili Mikro Besin (Temiz İsimler)
                            Text(
                              isTr ? 'İlişkili Mikro Besin' : 'Micro Nutrient',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: innerBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedMicroKey,
                                  isExpanded: true,
                                  style: TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w600),
                                  items: _allMicroOptions.map((opt) {
                                    return DropdownMenuItem<String>(
                                      value: opt.$1,
                                      child: Text('${opt.$2} (${opt.$1})'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final opt = _allMicroOptions.firstWhere((o) => o.$1 == val);
                                      setState(() {
                                        _selectedMicroKey = val;
                                        _selectedUnit = opt.$3;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Eklenen Miktar
                            TextField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: isTr ? 'Eklenen Miktar' : 'Amount',
                                suffixText: _selectedUnit,
                                filled: true,
                                fillColor: innerBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _handleAddFormSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: Text(
                                  isTr ? 'Takviyeyi Kaydet' : 'Save Supplement',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Supplements Header Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        isTr ? 'TAKVİYELERİM & BUGÜNKÜ DURUM' : 'MY SUPPLEMENTS & TODAY STATUS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),

                  // List of Supplements
                  if (_isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (_supplements.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            isTr ? 'Henüz kaydedilmiş takviyeniz yok.\nYukarıdaki + butonuna basarak ekleyin!' : 'No supplements configured yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final item = _supplements[index];
                          final takenDoses = _todayDosesMap[item.id] ?? 0;
                          final calculatedTimes = item.getCalculatedDoseTimes();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Optional Thumbnail Image
                                    if (item.imagePath != null && File(item.imagePath!).existsSync())
                                      Padding(
                                        padding: const EdgeInsets.only(right: 12),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(
                                            File(item.imagePath!),
                                            width: 36,
                                            height: 36,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.timesPerDay}x / ${isTr ? 'gün' : 'day'}' +
                                                (item.microNutrientKey != null && item.microAmount != null && item.microAmount! > 0
                                                    ? ' • ${item.microNutrientKey} (+${item.microAmount} ${item.microUnit})'
                                                    : ''),
                                            style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Edit Pencil Button
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFFD97706), size: 20),
                                      onPressed: () => _openEditSheet(item),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Dosage Circles & Scheduled Times Row (Yan Yana Kaydırılabilir)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: List.generate(item.timesPerDay, (doseIndex) {
                                      final isDoseTaken = doseIndex < takenDoses;
                                      final doseTime = doseIndex < calculatedTimes.length ? calculatedTimes[doseIndex] : '08:00';

                                      return GestureDetector(
                                        onTap: () {
                                          final newCount = isDoseTaken ? doseIndex : doseIndex + 1;
                                          _updateDose(item.id, newCount);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 16),
                                          child: Column(
                                            children: [
                                              AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isDoseTaken
                                                      ? accentColor
                                                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                                  border: Border.all(
                                                    color: isDoseTaken ? accentColor : (isDark ? Colors.white30 : Colors.black26),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Icon(
                                                  isDoseTaken ? Icons.check_rounded : Icons.circle_outlined,
                                                  size: 18,
                                                  color: isDoseTaken ? Colors.white : (isDark ? Colors.white30 : Colors.black38),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                doseTime,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDoseTaken ? accentColor : textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: _supplements.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 36)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── APPLE-DESIGNED EDIT SUPPLEMENT SHEET ──
class _EditSupplementSheet extends StatefulWidget {
  final SupplementItem item;
  final List<SupplementItem> existingSupplements;
  final List<(String key, String displayName, String unit, String category)> allMicroOptions;
  final Function(SupplementItem) onSave;
  final Function(String) onDelete;

  const _EditSupplementSheet({
    required this.item,
    required this.existingSupplements,
    required this.allMicroOptions,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditSupplementSheet> createState() => _EditSupplementSheetState();
}

class _EditSupplementSheetState extends State<_EditSupplementSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late int _timesPerDay;
  String? _imagePath;
  late String _selectedMicroKey;
  late String _selectedUnit;
  late List<TimeOfDay> _customDoseTimes;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _amountCtrl = TextEditingController(
        text: widget.item.microAmount != null ? widget.item.microAmount.toString() : '');
    _timesPerDay = widget.item.timesPerDay;
    _imagePath = widget.item.imagePath;
    _selectedMicroKey = widget.item.microNutrientKey ?? 'D-Vit';
    _selectedUnit = widget.item.microUnit;

    final existingTimes = widget.item.getCalculatedDoseTimes();
    _customDoseTimes = existingTimes.map((t) {
      final parts = t.split(':');
      final h = int.tryParse(parts.first) ?? 8;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return TimeOfDay(hour: h, minute: m);
    }).toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _updateDoseTimeSlots(int times) {
    _timesPerDay = times;
    if (times == 1) {
      _customDoseTimes = [const TimeOfDay(hour: 8, minute: 0)];
    } else if (times == 2) {
      _customDoseTimes = [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 20, minute: 0)];
    } else if (times == 3) {
      _customDoseTimes = [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 14, minute: 0), const TimeOfDay(hour: 20, minute: 0)];
    } else if (times == 4) {
      _customDoseTimes = [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 12, minute: 0), const TimeOfDay(hour: 16, minute: 0), const TimeOfDay(hour: 20, minute: 0)];
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file != null) {
      setState(() {
        _imagePath = file.path;
      });
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final isDuplicate = widget.existingSupplements.any(
      (s) => s.id != widget.item.id && s.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bu isimde bir takviye zaten ekli!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    final doseTimeStrs = _customDoseTimes
        .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .toList();

    final updated = SupplementItem(
      id: widget.item.id,
      name: name,
      timesPerDay: _timesPerDay,
      reminderTime: doseTimeStrs.isNotEmpty ? doseTimeStrs.first : '08:00',
      doseTimes: doseTimeStrs,
      microNutrientKey: _selectedMicroKey,
      microAmount: amount,
      microUnit: _selectedUnit,
      imagePath: _imagePath,
    );

    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final innerBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF8E8E93);
    final accentColor = const Color(0xFFD97706);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Takviyeyi Düzenle',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: _imagePath != null && File(_imagePath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(_imagePath!), width: 38, height: 38, fit: BoxFit.cover),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: innerBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.camera_alt_rounded, size: 14, color: Color(0xFFD97706)),
                              SizedBox(width: 4),
                              Text('Görsel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Takviye İsmi',
                filled: true,
                fillColor: innerBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),

            // Times Per Day
            Text('Günde Kaç Kere Alınacak?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CupertinoSegmentedControl<int>(
                selectedColor: accentColor,
                borderColor: accentColor,
                groupValue: _timesPerDay,
                children: const {
                  1: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('1 Defa')),
                  2: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('2 Defa')),
                  3: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('3 Defa')),
                  4: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('4 Defa')),
                },
                onValueChanged: (val) => setState(() => _updateDoseTimeSlots(val)),
              ),
            ),
            const SizedBox(height: 14),

            // Dose Times Chips (Yan yana kaydırılabilir)
            Text('Doz Saatleri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(_timesPerDay, (i) {
                  final time = i < _customDoseTimes.length ? _customDoseTimes[i] : const TimeOfDay(hour: 8, minute: 0);
                  final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: time);
                        if (t != null) {
                          setState(() {
                            if (i < _customDoseTimes.length) {
                              _customDoseTimes[i] = t;
                            }
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                      icon: const Icon(Icons.access_time_rounded, size: 14),
                      label: Text('${i + 1}. Doz: $timeStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),

            // Micro Nutrient Dropdown (Temiz isimler)
            Text('İlişkili Mikro Besin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: innerBg, borderRadius: BorderRadius.circular(14)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMicroKey,
                  isExpanded: true,
                  style: TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w600),
                  items: widget.allMicroOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt.$1,
                      child: Text('${opt.$2} (${opt.$1})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final opt = widget.allMicroOptions.firstWhere((o) => o.$1 == val);
                      setState(() {
                        _selectedMicroKey = val;
                        _selectedUnit = opt.$3;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Eklenen Miktar',
                suffixText: _selectedUnit,
                filled: true,
                fillColor: innerBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons (Save & Delete)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      widget.onDelete(widget.item.id);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Güncelle', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
