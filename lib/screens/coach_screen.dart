import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
            title: Text(context.tr('Geçmiş Yok')),
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
                initialChildSize: 0.7,
                minChildSize: 0.4,
                maxChildSize: 0.95,
                expand: false,
                builder: (sheetCtx, ctrl) => Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text('Geçmiş Konuşmalar',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                            if (selectedDate != null)
                              TextButton(
                                onPressed: () => setSheetState(() => selectedDate = null),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                ),
                                child: Text(
                                  '${selectedDate!.day}.${selectedDate!.month}.${selectedDate!.year} ✕',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                                color: selectedDate != null
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
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
                      const Divider(height: 1),
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
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: ctrl,
                              itemCount: sortedHistory.length,
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
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 20),
                                    color: Colors.amber,
                                    child: Icon(isFavorite ? Icons.star_border : Icons.star, color: Colors.white),
                                  ),
                                  secondaryBackground: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    color: Colors.red,
                                    child: const Icon(Icons.delete_outline, color: Colors.white),
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
                                  child: ListTile(
                                    leading: Icon(isFavorite ? Icons.star : Icons.chat_bubble_outline,
                                        color: isFavorite ? Colors.amber : null),
                                    title: Text('${archivedAt.day}.${archivedAt.month}.${archivedAt.year}',
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text('$preview…', maxLines: 1, overflow: TextOverflow.ellipsis),
                                    trailing: Text('${msgs.length} ${context.tr('mesaj')}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                                    onTap: () {
                                      _showConversationDetailExternal(context, session);
                                    },
                                  ),
                                );
                              },
                            );
                          }
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
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${archivedAt.day}.${archivedAt.month}.${archivedAt.year}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: dCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final isUser = m.isUser;
                    final content = m.content;
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.15)
                              : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: RichText(text: TextSpan(children: _parseMarkdownSpans(content, Theme.of(ctx).colorScheme.onSurface))),
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

class _CoachScreenState extends State<CoachScreen> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  List<String> _currentQuestions = [];
  List<String> _symptomQuestions = [];

  String get _apiKey => ConfigService.anthropicKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentQuestions = _buildDynamicQuestions(context);
    _symptomQuestions = _buildSymptomQuestions(context);
    // Start at the bottom
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      context.read<CoachProvider>().archiveSession();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coachProv = context.watch<CoachProvider>();
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
    WidgetsBinding.instance.removeObserver(this);
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
          title: Text(context.tr('Geçmiş Yok')),
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
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, ctrl) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Geçmiş Konuşmalar',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const Divider(height: 1),
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

                      return ListView.builder(
                        controller: ctrl,
                        itemCount: sortedHistory.length,
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
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              color: Colors.amber,
                              child: Icon(isFavorite ? Icons.star_border : Icons.star, color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                coach.toggleFavorite(session.archivedAt);
                                return false; 
                              }
                              return true; // Delete
                            },
                            onDismissed: (_) async {
                              coach.deleteSession(session.archivedAt);
                            },
                            child: ListTile(
                              leading: Icon(isFavorite ? Icons.star : Icons.chat_bubble_outline, 
                                  color: isFavorite ? Colors.amber : null),
                              title: Text('${archivedAt.day}.${archivedAt.month}.${archivedAt.year}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('$preview…', maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Text('${msgs.length} ${context.tr('mesaj')}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                              onTap: () => _showConversationDetail(context, session),
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
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${archivedAt.day}.${archivedAt.month}.${archivedAt.year}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final isUser = m.isUser;
                    final content = m.content;
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.15)
                              : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: RichText(text: TextSpan(children: _parseMarkdownSpans(content, Theme.of(ctx).colorScheme.onSurface))),
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

    return context.tr('coach_detailed_prompt')
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
  }

  Future<void> _sendMessage(String text, {String? displayText}) async {
    if (text.trim().isEmpty) return;
    _textController.clear();

    final coachProv = context.read<CoachProvider>();

    // Show displayText (short version) in bubble, but send 'text' (long version) to AI
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

      // Build conversation history (last 10 messages)
      final historyMsgs = coachProv.currentMessages.length > 10
          ? coachProv.currentMessages.sublist(coachProv.currentMessages.length - 10)
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
            {'role': 'user', 'content': text} // Send the LONG version to AI
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
        // Double scroll to ensure we catch the new message height after rebuild
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
        // Only auto-scroll if near bottom or forced
        if (force || (pos.maxScrollExtent - pos.pixels < 120)) {
          _scrollController.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Widget _buildChatBody(BuildContext context) {
    final coach = context.watch<CoachProvider>();
    // Set to 0 for a seamless connection with the tab bar
    final bottomPadding = widget.isEmbedded ? (MediaQuery.of(context).padding.bottom + 0) : 0.0;
    
    return WaveBackground(
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Column(
              children: [
                Expanded(
                  child: coach.currentMessages.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: coach.currentMessages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == coach.currentMessages.length && _isTyping) {
                              return _buildTypingIndicator(context);
                            }
                            return _buildMessageBubble(context, coach.currentMessages[index]);
                          },
                        ),
                ),
                if (!widget.isDialog)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 4),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1C2128)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.history, size: 20),
                          color: const Color(0xFF58A6FF),
                          tooltip: context.tr('Geçmiş'),
                          onPressed: () => _showHistory(context),
                        ),
                      ),
                    ),
                  ),
                _buildQuickQuestions(context),
                _buildInputArea(context),
              ],
            ),
          ),

        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isDialog) {
      return Column(
        children: [
          // HIG title bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Transform.scale(scaleX: -1, child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                  context.tr('Beslenme Koçu'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF58A6FF),
                        ),
                      ),
                      Text(
                        'Kişisel asistanın',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.history,
                      color: colorScheme.onSurfaceVariant),
                  iconSize: 20,
                  tooltip: context.tr('Geçmiş'),
                  onPressed: () => _showHistory(context),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  iconSize: 20,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(child: _buildChatBody(context)),
        ],
      );
    }

    if (widget.isEmbedded) {
      return _buildChatBody(context);
    }

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: _buildChatBody(context),
      ),
    );
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

    // 1. Sabah soruları (06:00 - 12:00)
    if (hour >= 6 && hour < 12) {
      questions.add(context.tr('🍳 Kahvaltı önerisi?'));
      questions.add(context.tr('🗓️ Bugün ne yemeliyim?'));
    }

    // 2. Akşam/Gece soruları (19:00 - 06:00)
    if (hour >= 19 || hour < 6) {
      questions.add(context.tr('💤 Uyku dostu besinler?'));
      questions.add(context.tr('📊 Günümü değerlendir'));
    }

    // 3. Koşullu sorular
    if (nutrition.todayLog.exercises.isNotEmpty) {
      questions.add(context.tr('🏃‍♂️ Spor sonrası ne yemeliyim?'));
    }

    if (waterIntakeMl < waterGoalMl * 0.8) {
      questions.add(context.tr('💧 Su içme tüyoları?'));
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

    // Her zaman olan genel sorular
    questions.add(context.tr('🍎 Sağlıklı atıştırmalık?'));
    questions.add(context.tr('⚡ Metabolizma hızlandırma?'));
    questions.add(context.tr('🥗 Pratik öğle yemeği?'));

    questions.shuffle();
    return questions.take(4).toList();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Transform.scale(scaleX: -1, child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 44)),
          ),
          const SizedBox(height: 24),
          FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF58A6FF), Color(0xFF79C0FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: Text(
                    context.tr('Merhaba!'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('Ben senin beslenme koçunum.'),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              context.tr('Profil bilgilerine ve bugünkü verilerine göre sana özel öneriler sunabilirim. Nereden başlayalım?'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAiAvatar(context),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const _TypingStatusText(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, CoachMessage message) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final profile = context.read<ProfileProvider>().activeProfile;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAiAvatar(context),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: RichText(
                text: TextSpan(
                  children: _parseMarkdown(
                    message.content,
                    isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(context, profile),
        ],
      ),
    );
  }

  Widget _buildAiAvatar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Transform.scale(scaleX: -1, child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20)),
    );
  }

  Widget _buildUserAvatar(BuildContext context, UserProfile? profile) {
    final cs = Theme.of(context).colorScheme;
    if (profile?.imagePath != null && File(profile!.imagePath!).existsSync()) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: FileImage(File(profile.imagePath!)),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF58A6FF).withValues(alpha: 0.2), // Same as profile screen
      child: Text(
        profile?.name.isNotEmpty == true ? profile!.name[0].toUpperCase() : 'U',
        style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 12, fontWeight: FontWeight.bold),
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
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: allItems.length,
        itemBuilder: (context, index) {
          final (isSymptom, itemIndex) = allItems[index];
          final label = isSymptom ? _symptomQuestions[itemIndex] : _currentQuestions[itemIndex];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSymptom
                        ? (isDark ? const Color(0xFFFFCDD2) : const Color(0xFFC62828))
                        : null,
                    fontWeight: isSymptom ? FontWeight.w600 : FontWeight.normal,
                  )),
              onPressed: () {
                final label = isSymptom ? _symptomQuestions[itemIndex] : _currentQuestions[itemIndex];
                String prompt = label;

                // Symptom-specific prompt
                if (isSymptom) {
                  final symptomText = label.replaceAll('🚨 ', '').replaceAll(context.tr('🚨 {} ile beslenme bağlantısı?').replaceFirst('{}', ''), '');
                  prompt = context.tr('prompt_symptom').replaceFirst('{symptom}', symptomText);
                } else if (label.contains(context.tr('🍳 Kahvaltı önerisi?').replaceAll('🍳 ', ''))) {
                  prompt = context.tr('prompt_breakfast');
                } else if (label.contains(context.tr('Akşam Yemeği').replaceAll(' Yemeği', '')) || label.contains('Akşam')) { // Fallback for 'Akşam' logic
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
                } else if (label.contains('egzersiz')) { // extra fallback
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
              backgroundColor: isSymptom
                  ? (isDark ? const Color(0xFF5C1A1A) : const Color(0xFFFFCDD2))
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              side: isSymptom
                  ? BorderSide(color: isDark ? const Color(0xFFEF9A9A) : const Color(0xFFEF5350), width: 0.8)
                  : BorderSide.none,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final bottomPadding = widget.isEmbedded ? 16.0 : (44.0 + safeAreaBottom);

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.tr('Koçuna bir şey sor...'),
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward),
              color: colorScheme.onPrimary,
              onPressed: () => _sendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Markdown parser (top-level so history sheet can use it) ─────────────────

List<TextSpan> _parseMarkdownSpans(String text, Color baseColor, {double fontSize = 13}) {
  final spans = <TextSpan>[];
  final regex = RegExp(r'\*\*(.*?)\*\*');
  int lastEnd = 0;
  for (final m in regex.allMatches(text)) {
    if (m.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, m.start), style: TextStyle(color: baseColor, fontSize: fontSize)));
    }
    spans.add(TextSpan(text: m.group(1), style: TextStyle(color: baseColor, fontSize: fontSize, fontWeight: FontWeight.w900)));
    lastEnd = m.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: TextStyle(color: baseColor, fontSize: fontSize)));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: TextStyle(color: baseColor, fontSize: fontSize)));
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: Text(
            _messages[_index],
            key: ValueKey(_index),
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: cs.onSurface),
          ),
        ),
        const SizedBox(width: 4),
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
    final color = Theme.of(context).colorScheme.onSurface;
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
