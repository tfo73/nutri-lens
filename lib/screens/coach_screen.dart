import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/coach_provider.dart';
import '../providers/wellness_provider.dart';
import '../services/config_service.dart';
import '../widgets/wave_background.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoachScreen extends StatefulWidget {
  final bool isDialog;
  final bool isEmbedded;
  const CoachScreen({super.key, this.isDialog = false, this.isEmbedded = false});

  @override
  State<CoachScreen> createState() => _CoachScreenState();

  // External access to history sheet
  Future<void> showHistoryExternal(BuildContext context) async {
    final coachProv = context.read<CoachProvider>();
    final history = coachProv.history;

    if (history.isEmpty) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(context.tr('Geçmiş Yok'), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(context.tr('Henüz kaydedilmiş bir konuşma geçmişiniz bulunmuyor.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Tamam'))),
            ],
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          DateTime? selectedDate;
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.75,
                minChildSize: 0.4,
                maxChildSize: 0.95,
                expand: false,
                builder: (sheetCtx, ctrl) => Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // iOS Drag Handle Bar
                      Container(
                        width: 36, height: 5,
                        margin: const EdgeInsets.only(top: 10, bottom: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.tr('Geçmiş Konuşmalar'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.4),
                              ),
                            ),
                            if (selectedDate != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: TextButton(
                                  onPressed: () => setSheetState(() => selectedDate = null),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    minimumSize: Size.zero,
                                  ),
                                  child: Text(
                                    '${selectedDate!.day}.${selectedDate!.month}.${selectedDate!.year} ✕',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF007AFF), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                                color: selectedDate != null ? const Color(0xFF007AFF) : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate ?? now,
                                  firstDate: DateTime(now.year - 2),
                                  lastDate: now,
                                );
                                if (picked != null) {
                                  setSheetState(() => selectedDate = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                      Expanded(
                        child: Consumer<CoachProvider>(
                          builder: (ctx2, coach, _) {
                            var sortedHistory = List<CoachSession>.from(coach.history);
                            sortedHistory.sort((a, b) {
                              if (a.isFavorite != b.isFavorite) return b.isFavorite ? 1 : -1;
                              if (a.isFavorite) {
                                final aFavTime = DateTime.tryParse(a.favoritedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                                final bFavTime = DateTime.tryParse(b.favoritedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                                return bFavTime.compareTo(aFavTime);
                              } else {
                                final aTime = DateTime.tryParse(a.archivedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
                                final bTime = DateTime.tryParse(b.archivedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
                                return bTime.compareTo(aTime);
                              }
                            });

                            if (selectedDate != null) {
                              sortedHistory = sortedHistory.where((s) {
                                final d = DateTime.tryParse(s.archivedAt);
                                return d != null &&
                                    d.year == selectedDate!.year &&
                                    d.month == selectedDate!.month &&
                                    d.day == selectedDate!.day;
                              }).toList();
                            }

                            if (sortedHistory.isEmpty) {
                              return Center(
                                child: Text(
                                  selectedDate != null
                                      ? context.tr('Bu tarihte konuşma yok')
                                      : context.tr('Geçmiş bulunamadı'),
                                  style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 15),
                                ),
                              );
                            }

                            return ListView.separated(
                              controller: ctrl,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: sortedHistory.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final session = sortedHistory[i];
                                final archivedAt = DateTime.tryParse(session.archivedAt) ?? DateTime.now();
                                final isFavorite = session.isFavorite;
                                final msgs = session.messages;
                                final preview = msgs.isNotEmpty
                                    ? msgs.first.content.substring(0, msgs.first.content.length.clamp(0, 60))
                                    : '';

                                return Dismissible(
                                  key: ValueKey('${session.archivedAt}-$isFavorite'),
                                  direction: DismissDirection.horizontal,
                                  background: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 20),
                                    child: Icon(isFavorite ? Icons.star_border_rounded : Icons.star_rounded, color: Colors.white),
                                  ),
                                  secondaryBackground: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3B30),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                  ),
                                  confirmDismiss: (direction) async {
                                    if (direction == DismissDirection.startToEnd) {
                                      coach.toggleFavorite(session.archivedAt);
                                      return false;
                                    }
                                    return true;
                                  },
                                  onDismissed: (_) async {
                                    coach.deleteSession(session.archivedAt);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isFavorite
                                              ? Colors.amber.withValues(alpha: 0.15)
                                              : const Color(0xFF007AFF).withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isFavorite ? Icons.star_rounded : Icons.chat_bubble_outline_rounded,
                                          color: isFavorite ? Colors.amber.shade700 : const Color(0xFF007AFF),
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        '${archivedAt.day}.${archivedAt.month}.${archivedAt.year}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      subtitle: Text(
                                        '$preview…',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${msgs.length} ${context.tr('mesaj')}',
                                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      onTap: () {
                                        _showConversationDetailExternal(context, session);
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

  static void _showConversationDetailExternal(BuildContext context, CoachSession session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final msgs = session.messages;
    final archivedAt = DateTime.tryParse(session.archivedAt) ?? DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, dCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 36, height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2.5)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${archivedAt.day}.${archivedAt.month}.${archivedAt.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: -0.4),
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
              Expanded(
                child: ListView.builder(
                  controller: dCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final isUser = m.isUser;
                    final content = m.content;
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.78),
                        decoration: BoxDecoration(
                          color: isUser
                              ? const Color(0xFF007AFF)
                              : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: _parseMarkdownSpans(
                              content,
                              isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachScreenState extends State<CoachScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  List<String> _currentQuestions = [];
  List<String> _symptomQuestions = [];
  Map<String, dynamic>? _onboardingAnswers;

  String _randomFeatureText = '';
  String? _lastSessionId;
  int _lastMessageCount = -1;

  String get _apiKey => ConfigService.anthropicKey;

  void _rollRandomFeatureText() {
    final features = [
      context.tr('Yediğin yemeğin fotoğrafını çekerek veya yazarak kalori ve porsiyon analizi yapabilirim.'),
      context.tr('Profilindeki alerji, hassasiyet ve sağlık durumlarına göre tamamen güvenli tarifler üretebilirim.'),
      context.tr('Kilo alma veya verme hedefine uygun günlük porsiyon ve menü planlamaları hazırlayabilirim.'),
      context.tr('Bugünkü kalori, makro ve su tüketim durumunu inceleyip gününü değerlendirebilirim.'),
      context.tr('Spor sonrası kas yenilenmesi veya enerji kazanımı için en uygun öğünleri önerebilirim.'),
      context.tr('Metabolizmanı hızlandıracak pratik tarifler ve sağlıklı atıştırmalık alternatifleri sunabilirim.'),
      context.tr('Öğünlerinin protein, karbonhidrat ve yağ dengesini analiz edip sana özel tavsiyeler verebilirim.'),
    ];
    features.shuffle();
    setState(() {
      _randomFeatureText = features.first;
    });
  }

  @override
  void initState() {
    super.initState();
    _symptomQuestions = _buildSymptomQuestions(context);
    _loadOnboardingAnswers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rollRandomFeatureText();
      setState(() {
        _currentQuestions = _buildDynamicQuestions(context);
      });
      _scrollToBottom(force: true);
    });
  }

  Future<void> _loadOnboardingAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final answersStr = prefs.getString('onboarding_answers');
      if (answersStr != null) {
        setState(() {
          _onboardingAnswers = jsonDecode(answersStr);
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coachProv = context.watch<CoachProvider>();
    
    // Check if session changed or conversation was cleared (New Session)
    if (coachProv.selectedSessionId != _lastSessionId || 
        coachProv.currentMessages.length != _lastMessageCount) {
      final oldSessionId = _lastSessionId;
      _lastSessionId = coachProv.selectedSessionId;
      _lastMessageCount = coachProv.currentMessages.length;
      
      // Roll random feature sentence and shuffle questions on session change/clear
      if (coachProv.currentMessages.isEmpty || coachProv.selectedSessionId != oldSessionId) {
        _rollRandomFeatureText();
        _currentQuestions = _buildDynamicQuestions(context);
      }
    }

    if (coachProv.prefilledMessage != null) {
      _textController.text = coachProv.prefilledMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CoachProvider>().clearPrefilledMessage();
      });
    }
  }

  @override
  void deactivate() {
    FocusScope.of(context).unfocus();
    super.deactivate();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showHistory(BuildContext context) async {
    final coachProv = context.read<CoachProvider>();
    final history = coachProv.history;

    if (history.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(context.tr('Geçmiş Yok'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(context.tr('Henüz kaydedilmiş bir konuşma geçmişiniz bulunmuyor.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Tamam'))),
          ],
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, ctrl) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36, height: 5,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    context.tr('Geçmiş Konuşmalar'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.4),
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                Expanded(
                  child: Consumer<CoachProvider>(
                    builder: (ctx, coach, _) {
                      final sortedHistory = List<CoachSession>.from(coach.history);
                      sortedHistory.sort((a, b) {
                        if (a.isFavorite != b.isFavorite) return b.isFavorite ? 1 : -1;
                        if (a.isFavorite) {
                          final aFavTime = DateTime.tryParse(a.favoritedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                          final bFavTime = DateTime.tryParse(b.favoritedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                          return bFavTime.compareTo(aFavTime);
                        } else {
                          final aTime = DateTime.tryParse(a.archivedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
                          final bTime = DateTime.tryParse(b.archivedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
                          return bTime.compareTo(aTime);
                        }
                      });

                      return ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: sortedHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final session = sortedHistory[i];
                          final archivedAt = DateTime.tryParse(session.archivedAt) ?? DateTime.now();
                          final isFavorite = session.isFavorite;
                          final msgs = session.messages;
                          final preview = msgs.isNotEmpty
                              ? msgs.first.content.substring(0, msgs.first.content.length.clamp(0, 60))
                              : '';

                          return Dismissible(
                            key: ValueKey('${session.archivedAt}-$isFavorite'),
                            direction: DismissDirection.horizontal,
                            background: Container(
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              child: Icon(isFavorite ? Icons.star_border_rounded : Icons.star_rounded, color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                coach.toggleFavorite(session.archivedAt);
                                return false;
                              }
                              return true;
                            },
                            onDismissed: (_) async {
                              coach.deleteSession(session.archivedAt);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isFavorite
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : const Color(0xFF007AFF).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isFavorite ? Icons.star_rounded : Icons.chat_bubble_outline_rounded,
                                    color: isFavorite ? Colors.amber.shade700 : const Color(0xFF007AFF),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '${archivedAt.day}.${archivedAt.month}.${archivedAt.year}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  '$preview…',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${msgs.length} ${context.tr('mesaj')}',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                onTap: () => _showConversationDetail(context, session),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConversationDetail(BuildContext context, CoachSession session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final msgs = session.messages;
    final archivedAt = DateTime.tryParse(session.archivedAt) ?? DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, ctrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 36, height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2.5)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${archivedAt.day}.${archivedAt.month}.${archivedAt.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: -0.4),
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final isUser = m.isUser;
                    final content = m.content;
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.78),
                        decoration: BoxDecoration(
                          color: isUser
                              ? const Color(0xFF007AFF)
                              : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: _parseMarkdownSpans(
                              content,
                              isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSystemPrompt(BuildContext context) {
    final profile = context.read<ProfileProvider>().activeProfile;
    final nutrition = context.read<NutritionProvider>();
    final today = nutrition.totalNutrition;
    final calorieGoal = context.read<ProfileProvider>().calorieGoal;

    if (profile == null) {
      return context.tr('coach_fallback_prompt');
    }

    // Build onboarding profile summary
    final diseases = _onboardingAnswers?['diseases'] as List? ?? profile.healthConditions;
    final diseasesStr = diseases.isNotEmpty ? diseases.join(', ') : 'Belirtilmemiş';
    final sensitivities = _onboardingAnswers?['foodSensitivities'] as List? ?? [];
    final sensitivitiesOther = _onboardingAnswers?['foodSensitivitiesOther'] as String? ?? '';
    final sensitivitiesStr = (sensitivities.isNotEmpty || sensitivitiesOther.isNotEmpty)
        ? '${sensitivities.join(', ')} ${sensitivitiesOther.isNotEmpty ? "($sensitivitiesOther)" : ""}'
        : 'Belirtilmemiş';
    final targetW = _onboardingAnswers?['targetWeightKg'] ?? '';

    final onboardingContext = '\n\n'
        'SAĞLIK VE GÜVENLİK PROFİLİ:\n'
        '- Hastalıklar: $diseasesStr\n'
        '- Hassasiyetler / Alerjiler: $sensitivitiesStr\n'
        '- Diyet Planı: ${profile.dietaryPreferences.isNotEmpty ? profile.dietaryPreferences.join(', ') : "Belirtilmemiş"}\n'
        '- Hedef Kilo: $targetW kg\n\n'
        'KRİTİK GÜVENLİK TALİMATLARI:\n'
        '1. GÜVENLİK BİRİNCİ ÖNCELİKTİR: Kullanıcının alerjisi veya hassasiyeti olduğu belirtilen gıdaları (Örn: Glüten/Çölyak, Laktoz, Fındık vb.) içeren veya tetikleyen besinleri, yemekleri ya da tarifleri KESİNLİKLE önerme ve kullanma!\n'
        '2. PORSİYON BİLGİSİ VERME: Kullanıcı eğer bir plan yapmanı, tarif vermeni veya öğün önermeni istiyorsa, kalori değerlerinin yanında mutlaka net porsiyon/servis miktarları (Örn: 1 kase, 150 gram, 2 dilim) da ver. Sadece kalori değerini vermek yemek yaparken veya porsiyon ayarlarken yeterli değildir.\n'
        '3. Bu profile ve yukarıdaki kısıtlamalara tam uyum sağla. Türkçe ve kısa/öz yanıt ver.';

    final basePrompt = context.tr('coach_detailed_prompt')
        .replaceFirst('{name}', profile.name)
        .replaceFirst('{age}', profile.age.toString())
        .replaceFirst('{height}', profile.height.toStringAsFixed(0))
        .replaceFirst('{weight}', profile.weight.toStringAsFixed(1))
        .replaceFirst('{goal}', profile.goalLabel)
        .replaceFirst('{activity}', profile.activityLabel)
        .replaceFirst('{calories}', today.calories.toStringAsFixed(0))
        .replaceFirst('{calGoal}', calorieGoal.toStringAsFixed(0))
        .replaceFirst('{protein}', today.protein.toStringAsFixed(1))
        .replaceFirst('{proGoal}', profile.proteinGoal.toStringAsFixed(0))
        .replaceFirst('{carb}', today.carbohydrates.toStringAsFixed(1))
        .replaceFirst('{carbGoal}', profile.carbGoal.toStringAsFixed(0))
        .replaceFirst('{fat}', today.fat.toStringAsFixed(1))
        .replaceFirst('{fatGoal}', profile.fatGoal.toStringAsFixed(0))
        .replaceFirst('{name}', profile.name);

    return '$basePrompt$onboardingContext';
  }

  Future<void> _sendMessage(String text, {String? displayText}) async {
    if (text.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _textController.clear();

    final coachProv = context.read<CoachProvider>();

    if (text.trim().length <= 1) {
      final userMsg = CoachMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: (displayText ?? text).trim(),
        isUser: true,
        timestamp: DateTime.now(),
      );

      coachProv.addMessage(userMsg);
      setState(() {
        _isTyping = true;
      });
      _scrollToBottom(force: true);

      await Future.delayed(const Duration(milliseconds: 600));
      final fallbackMsg = CoachMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        content: context.tr('Anlayamadım, lütfen tekrar yazar mısınız?'),
        isUser: false,
        timestamp: DateTime.now(),
      );

      coachProv.addMessage(fallbackMsg);
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom(force: true);
      return;
    }

    final userMsg = CoachMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: (displayText ?? text).trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    coachProv.addMessage(userMsg);
    setState(() {
      _isTyping = true;
    });
    _scrollToBottom(force: true);

    try {
      final systemPrompt = _buildSystemPrompt(context);

      final historyMsgs = coachProv.currentMessages.length > 20
          ? coachProv.currentMessages.sublist(coachProv.currentMessages.length - 20)
          : List<CoachMessage>.from(coachProv.currentMessages);

      final apiMessages = historyMsgs.map((m) => {
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.content,
          }).toList();

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 512,
          'system': systemPrompt,
          'messages': [
            ...apiMessages.sublist(0, apiMessages.length - 1),
            {'role': 'user', 'content': text}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        String replyText =
            (data['content'] as List<dynamic>)[0]['text'] as String;

        final lines = replyText.split('\n');
        if (lines.isNotEmpty && lines.first.toLowerCase().contains('öneri')) {
          replyText = lines.skip(1).join('\n').trim();
        }

        final aiMsg = CoachMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_ai',
          content: replyText,
          isUser: false,
          timestamp: DateTime.now(),
        );

        coachProv.addMessage(aiMsg);
        setState(() {
          _isTyping = false;
        });
        _scrollToBottom(force: true);
        Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom(force: true));
      } else {
        _addErrorMessage(context.tr('API hatası: {}').replaceFirst('{}', response.statusCode.toString()));
      }
    } catch (e) {
      _addErrorMessage(context.tr('Bağlantı hatası. Lütfen tekrar deneyin.'));
    }
    _scrollToBottom(force: true);
  }

  void _addErrorMessage(String text) {
    context.read<CoachProvider>().addMessage(CoachMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_err',
          content: text,
          isUser: false,
          timestamp: DateTime.now(),
        ));
    setState(() {
      _isTyping = false;
    });
    _scrollToBottom(force: true);
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final pos = _scrollController.position;
        if (force || (pos.maxScrollExtent - pos.pixels < 120)) {
          _scrollController.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  Widget _buildTopHeader(BuildContext context) {
    if (!widget.isDialog) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.85)
                : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              const Spacer(),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 19,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderMain(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(
                  Icons.menu_rounded, 
                  color: _isTyping ? cs.onSurface.withValues(alpha: 0.3) : cs.onSurface, 
                  size: 28
                ),
                onPressed: _isTyping ? null : () {
                  Scaffold.of(ctx).openDrawer();
                },
              ),
            ),
            const SizedBox(width: 4),
            Text(
              context.tr('Dijital İkiz'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: -0.5,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody(BuildContext context) {
    final coach = context.watch<CoachProvider>();

    return WaveBackground(
      child: Column(
        children: [
          if (widget.isDialog) 
            _buildTopHeader(context)
          else if (!widget.isEmbedded)
            _buildTopHeaderMain(context),
          Expanded(
            child: coach.currentMessages.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: coach.currentMessages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == coach.currentMessages.length && _isTyping) {
                        return _buildTypingIndicator(context);
                      }
                      return _buildMessageBubble(context, coach.currentMessages[index]);
                    },
                  ),
          ),
          _buildQuickQuestions(context),
          _buildInputArea(context),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _buildChatBody(context),
          ),
        ),
      );
    }

    if (widget.isEmbedded) {
      return _buildChatBody(context);
    }

    return _buildChatBody(context);
  }

  List<String> _buildSymptomQuestions(BuildContext context) {
    try {
      final wellness = context.read<WellnessProvider>();
      final symptoms = wellness.today.symptoms;
      if (symptoms.isEmpty) return [];
      return symptoms.take(2).map((s) => context.tr('🚨 {} ile beslenme bağlantısı?').replaceFirst('{}', s)).toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _buildDynamicQuestions(BuildContext context) {
    final hour = DateTime.now().hour;
    final nutrition = context.read<NutritionProvider>();
    final profile = context.read<ProfileProvider>().activeProfile;
    final today = nutrition.totalNutrition;
    final calorieGoal = context.read<ProfileProvider>().calorieGoal;
    final waterIntakeMl = nutrition.todayLog.waterIntakeMl;
    final waterGoalMl = context.read<ProfileProvider>().waterGoalMl.toDouble();

    final questions = <String>[];

    if (hour >= 6 && hour < 12) {
      questions.add(context.tr('🍳 Kahvaltı önerisi?'));
      questions.add(context.tr('🗓️ Bugün ne yemeliyim?'));
      questions.add(context.tr('☀️ Güne enerjik başlama tüyoları?'));
      questions.add(context.tr('☕ Kahve yanında sağlıklı ne yiyebilirim?'));
    }

    if (hour >= 19 || hour < 6) {
      questions.add(context.tr('💤 Uyku dostu besinler?'));
      questions.add(context.tr('📊 Günümü değerlendir'));
      questions.add(context.tr('🍵 Gece açlığını yatıştıracak tarif?'));
      questions.add(context.tr('Akşam ne yemeliyim?'));
    }

    if (nutrition.todayLog.exercises.isNotEmpty) {
      questions.add(context.tr('🏃‍♂️ Spor sonrası ne yemeliyim?'));
      questions.add(context.tr('🏋️‍♂️ Spor öncesi enerji öğünleri?'));
    }

    if (waterIntakeMl < waterGoalMl * 0.8) {
      questions.add(context.tr('💧 Su içme tüyoları?'));
      questions.add(context.tr('🥤 Aromalı su tarifleri?'));
    }

    if (calorieGoal > 0 && today.calories < calorieGoal * 0.7) {
      questions.add(context.tr('⚖️ Kalori açığı tavsiyesi?'));
    }

    if (profile != null) {
      if (profile.proteinGoal > 0 && today.protein < profile.proteinGoal * 0.7) {
        questions.add(context.tr('🍗 Protein hedefi?'));
      }
      if (profile.carbGoal > 0 && today.carbohydrates < profile.carbGoal * 0.7) {
        questions.add(context.tr('🥖 Karbonhidrat desteği?'));
      }
      if (profile.fatGoal > 0 && today.fat < profile.fatGoal * 0.7) {
        questions.add(context.tr('🥑 Sağlıklı yağlar?'));
      }
    }

    questions.add(context.tr('🍎 Sağlıklı atıştırmalık?'));
    questions.add(context.tr('⚡ Metabolizma hızlandırma?'));
    questions.add(context.tr('🥗 Pratik öğle yemeği?'));
    questions.add(context.tr('🥦 Lif tüketimini artırma yolları?'));
    questions.add(context.tr('🍬 Şeker krizini önleme yöntemleri?'));
    questions.add(context.tr('🔥 Yağ yakımını destekleyen besinler?'));
    questions.add(context.tr('🌾 Glütensiz beslenme tüyoları?'));
    questions.add(context.tr('🧁 Düşük kalorili tatlı tarifi?'));
    questions.add(context.tr('🍽️ Aralıklı oruç öğün planı?'));

    questions.shuffle();
    return questions.take(4).toList();
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Four corner brackets
                  // Top Left
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFFFC107), width: 3),
                          left: BorderSide(color: Color(0xFFFFC107), width: 3),
                        ),
                      ),
                    ),
                  ),
                  // Top Right
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFFFC107), width: 3),
                          right: BorderSide(color: Color(0xFFFFC107), width: 3),
                        ),
                      ),
                    ),
                  ),
                  // Bottom Left
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFFFC107), width: 3),
                          left: BorderSide(color: Color(0xFFFFC107), width: 3),
                        ),
                      ),
                    ),
                  ),
                  // Bottom Right
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFFFC107), width: 3),
                          right: BorderSide(color: Color(0xFFFFC107), width: 3),
                        ),
                      ),
                    ),
                  ),
                  
                  // 2. Centered rounded square container
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E222F),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFFFFC107),
                      size: 38,
                    ),
                  ),
                  
                  // 3. Overlapping bottom-right gold circle badge
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC107),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 3,
                            offset: Offset(0, 1.5),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.auto_awesome, // Sparkles
                        color: Color(0xFF1E222F),
                        size: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final profile = context.watch<ProfileProvider>().activeProfile;
                final name = profile != null ? ', ${profile.name.trim().split(' ').first}' : '';
                return Text(
                  '${context.tr('Merhaba')}$name!',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: -0.5,
                    color: Color(0xFF007AFF),
                  ),
                );
              }
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('Ben senin dijital ikizinim.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.4,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _randomFeatureText.isNotEmpty 
                  ? _randomFeatureText 
                  : context.tr('Profil bilgilerine ve bugünkü verilerine göre sana özel öneriler sunabilirim.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildTypingIndicator(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAiAvatar(context),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const _TypingStatusText(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, CoachMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;
    final profile = context.read<ProfileProvider>().activeProfile;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAiAvatar(context),
          if (!isUser) const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF007AFF)
                    : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: RichText(
                text: TextSpan(
                  children: _parseMarkdown(
                    message.content,
                    isUser ? Colors.white : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.87)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAvatar(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF58A6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Transform.scale(
        scaleX: -1,
        child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 19),
      ),
    );
  }



  List<TextSpan> _parseMarkdown(String text, Color baseColor) =>
      _parseMarkdownSpans(text, baseColor, fontSize: 14);

  Widget _buildQuickQuestions(BuildContext context) {
    final allItems = [
      ...List.generate(_symptomQuestions.length, (i) => (true, i)),
      ...List.generate(_currentQuestions.length, (i) => (false, i)),
    ];
    if (allItems.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 18, bottom: 6),
          child: Text(
            context.tr('Nereden başlayalım?'),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          height: 44,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final (isSymptom, itemIndex) = allItems[index];
              final label = isSymptom ? _symptomQuestions[itemIndex] : _currentQuestions[itemIndex];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      final label = isSymptom ? _symptomQuestions[itemIndex] : _currentQuestions[itemIndex];
                      String prompt = label;

                      if (isSymptom) {
                        final symptomText = label.replaceAll('🚨 ', '').replaceAll(context.tr('🚨 {} ile beslenme bağlantısı?').replaceFirst('{}', ''), '');
                        prompt = context.tr('prompt_symptom').replaceFirst('{symptom}', symptomText);
                      } else if (label.contains(context.tr('🍳 Kahvaltı önerisi?').replaceAll('🍳 ', ''))) {
                        prompt = context.tr('prompt_breakfast');
                      } else if (label.contains('Akşam')) {
                        prompt = context.tr('prompt_dinner');
                      } else if (label.contains('💧') || label.contains('Su')) {
                        prompt = context.tr('prompt_water');
                      } else if (label.contains('🏃‍♂️') || label.contains('Spor') || label.contains('Adım')) {
                        prompt = context.tr('prompt_steps');
                      } else if (label.contains('🍎') || label.contains('atıştırmalık')) {
                        prompt = context.tr('prompt_snack');
                      } else if (label.contains('⚡') || label.contains('Enerjim')) {
                        prompt = context.tr('prompt_energy');
                      } else if (label.contains('📊') || label.contains('değerlendir') || label.contains('Günümü')) {
                        prompt = context.tr('prompt_eval_day');
                      } else if (label.contains('egzersiz')) {
                        prompt = context.tr('prompt_post_workout');
                      } else if (label.contains('Metabolizma')) {
                        prompt = context.tr('prompt_metabolism');
                      } else if (label.contains('💤') || label.contains('Uyku')) {
                        prompt = context.tr('prompt_sleep');
                      } else if (label.contains('⚖️') || label.contains('Kalori')) {
                        prompt = context.tr('prompt_calorie');
                      } else if (label.contains('🍗') || label.contains('Protein')) {
                        prompt = context.tr('prompt_protein');
                      } else if (label.contains('🥖') || label.contains('Karbonhidrat')) {
                        prompt = context.tr('prompt_carb');
                      } else if (label.contains('🥑') || label.contains('yağlar')) {
                        prompt = context.tr('prompt_fat');
                      } else if (label.contains('🥗') || label.contains('Öğle')) {
                        prompt = context.tr('prompt_lunch');
                      }

                      _sendMessage(prompt);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSymptom
                            ? (isDark ? const Color(0xFF5C1A1A) : const Color(0xFFFFCDD2))
                            : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSymptom
                              ? (isDark ? const Color(0xFFEF9A9A) : const Color(0xFFEF5350))
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSymptom ? FontWeight.w600 : FontWeight.w500,
                            color: isSymptom
                                ? (isDark ? const Color(0xFFFFCDD2) : const Color(0xFFC62828))
                                : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final bottomPadding = widget.isEmbedded ? 12.0 : (8.0 + safeAreaBottom);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.85)
                : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _textController,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('Dijital ikizine bir şey sor...'),
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 15,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _textController,
                builder: (context, value, child) {
                  final hasText = value.text.trim().isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasText ? const Color(0xFF007AFF) : (isDark ? Colors.white12 : Colors.black12),
                      shape: BoxShape.circle,
                      boxShadow: hasText
                          ? [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      color: hasText ? Colors.white : (isDark ? Colors.white38 : Colors.black38),
                      onPressed: hasText ? () => _sendMessage(_textController.text) : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Markdown parser ─────────────────────────────────────────────────────────

List<TextSpan> _parseMarkdownSpans(String text, Color baseColor, {double fontSize = 14}) {
  final spans = <TextSpan>[];
  final regex = RegExp(r'\*\*(.*?)\*\*');
  int lastEnd = 0;
  for (final m in regex.allMatches(text)) {
    if (m.start > lastEnd) {
      spans.add(TextSpan(
        text: text.substring(lastEnd, m.start),
        style: TextStyle(color: baseColor, fontSize: fontSize, height: 1.45),
      ));
    }
    spans.add(TextSpan(
      text: m.group(1),
      style: TextStyle(color: baseColor, fontSize: fontSize, fontWeight: FontWeight.bold, height: 1.45),
    ));
    lastEnd = m.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastEnd),
      style: TextStyle(color: baseColor, fontSize: fontSize, height: 1.45),
    ));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(
      text: text,
      style: TextStyle(color: baseColor, fontSize: fontSize, height: 1.45),
    ));
  }
  return spans;
}

// ─── Typing Status Text Widget ────────────────────────────────────────────────

class _TypingStatusText extends StatefulWidget {
  const _TypingStatusText();
  @override
  State<_TypingStatusText> createState() => _TypingStatusTextState();
}

class _TypingStatusTextState extends State<_TypingStatusText> {
  List<String> get _messages => [
    context.tr('Öğünlerin inceleniyor'),
    context.tr('Kalori alışına bakılıyor'),
    context.tr('Besin değerlerin hesaplanıyor'),
    context.tr('Hedeflerinle karşılaştırılıyor'),
    context.tr('Günlük ilerleme analiz ediliyor'),
    context.tr('Önerin hazırlanıyor'),
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          child: Text(
            _messages[_index],
            key: ValueKey(_index),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const _AnimatedDots(),
      ],
    );
  }
}

// ─── Animated Dots Widget ────────────────────────────────────────────────────

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    ));
    _animations = _controllers.map((c) => Tween<double>(begin: 0.25, end: 1.0)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white70 : Colors.black87;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: FadeTransition(
          opacity: _animations[i],
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      )),
    );
  }
}

// ─── standalone public CoachDrawer ───────────────────────────────────────────

class CoachDrawer extends StatelessWidget {
  const CoachDrawer({super.key});

  Widget _buildDrawerItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.15), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? const Color(0xFF007AFF) : cs.onSurface.withValues(alpha: 0.5),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF007AFF) : cs.onSurface,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.4),
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null) 
                trailing
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.25),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String archivedAt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(context.tr('Konuşmayı Sil'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(context.tr('Bu konuşma geçmişini silmek istediğinize emin misiniz?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Vazgeç'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              context.read<CoachProvider>().deleteSession(archivedAt);
              Navigator.pop(ctx);
            },
            child: Text(context.tr('Sil'), style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatSessionDate(BuildContext context, String archivedAtStr) {
    final date = DateTime.tryParse(archivedAtStr);
    if (date == null) return archivedAtStr;
    
    final months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    
    return '${date.day} ${months[date.month]} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final coachProv = context.watch<CoachProvider>();
    final activeSessionId = coachProv.selectedSessionId;
    final history = coachProv.history;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      child: Column(
        children: [
          // Spacer for status bar/dynamic island
          SizedBox(height: MediaQuery.of(context).padding.top + 8),
          
          // Action Buttons - iOS subtle light tint button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: const Color(0xFF007AFF),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                context.tr('Yeni Konuşma Başlat'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
              ),
              onPressed: () {
                coachProv.startNewSession();
                Navigator.pop(context); // Close drawer
              },
            ),
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // Session List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Active Conversation Item
                _buildDrawerItem(
                  context: context,
                  title: context.tr('Aktif Konuşma'),
                  subtitle: coachProv.currentMessages.isNotEmpty 
                      ? coachProv.currentMessages.last.content 
                      : context.tr('Henüz konuşma başlamadı'),
                  isSelected: activeSessionId == null,
                  icon: Icons.chat_bubble_rounded,
                  onTap: () {
                    coachProv.selectSession(null);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                if (history.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
                    child: Text(
                      context.tr('Geçmiş Konuşmalar'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface.withValues(alpha: 0.45),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...history.map((session) {
                    final isSelected = activeSessionId == session.archivedAt;
                    final displayDate = _formatSessionDate(context, session.archivedAt);
                    final preview = session.messages.isNotEmpty 
                        ? session.messages.last.content 
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildDrawerItem(
                        context: context,
                        title: displayDate,
                        subtitle: preview,
                        isSelected: isSelected,
                        icon: Icons.history_rounded,
                        onTap: () {
                          coachProv.selectSession(session.archivedAt);
                          Navigator.pop(context);
                        },
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: cs.error.withValues(alpha: 0.6),
                          ),
                          onPressed: () {
                            _showDeleteConfirmation(context, session.archivedAt);
                          },
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
