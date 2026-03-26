import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';

class _ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  const _ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _ChatMessage(
        id: json['id'] as String,
        content: json['content'] as String,
        isUser: json['isUser'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class CoachScreen extends StatefulWidget {
  final bool isDialog;
  const CoachScreen({super.key, this.isDialog = false});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  final String apiKey = const String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');
  static const _maxMessages = 50;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _storageKey(BuildContext context) {
    final profileId = context.read<ProfileProvider>().activeProfileId;
    return 'coach_messages_$profileId';
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final key = _storageKey(context);
    final json = prefs.getString(key);
    if (json != null) {
      try {
        final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
        final msgs = decoded
            .map((e) => _ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() => _messages.addAll(msgs));
        _scrollToBottom();
      } catch (_) {}
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final key = _storageKey(context);
    final toSave = _messages.length > _maxMessages
        ? _messages.sublist(_messages.length - _maxMessages)
        : _messages;
    await prefs.setString(
        key, jsonEncode(toSave.map((m) => m.toJson()).toList()));
  }

  String _buildSystemPrompt(BuildContext context) {
    final profile = context.read<ProfileProvider>().activeProfile;
    final nutrition = context.read<NutritionProvider>();
    final today = nutrition.totalNutrition;
    final calorieGoal = context.read<ProfileProvider>().calorieGoal;

    if (profile == null) {
      return 'Sen bir uzman beslenme koçusun. Kullanıcıya Türkçe, kısa ve pratik öneriler sun.';
    }

    return '''Sen bir uzman beslenme koçusun. Kullanıcının profil bilgileri:
İsim: ${profile.name}, ${profile.age} yaşında, ${profile.height.toStringAsFixed(0)}cm boy, ${profile.weight.toStringAsFixed(1)}kg kilo.
Hedef: ${profile.goalLabel}, Aktivite: ${profile.activityLabel}.
Bugünkü beslenme özeti: ${today.calories.toStringAsFixed(0)} kcal alındı, hedef ${calorieGoal.toStringAsFixed(0)} kcal.
Protein: ${today.protein.toStringAsFixed(1)}g (hedef: ${profile.proteinGoal.toStringAsFixed(0)}g)
Karbonhidrat: ${today.carbohydrates.toStringAsFixed(1)}g (hedef: ${profile.carbGoal.toStringAsFixed(0)}g)
Yağ: ${today.fat.toStringAsFixed(1)}g (hedef: ${profile.fatGoal.toStringAsFixed(0)}g)

Türkçe yanıt ver. Kısa ve pratik öneriler sun. Maksimum 3-4 cümle kullan.''';
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();

    final userMsg = _ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final systemPrompt = _buildSystemPrompt(context);

      // Build conversation history (last 10 messages)
      final historyMsgs = _messages.length > 10
          ? _messages.sublist(_messages.length - 10)
          : List<_ChatMessage>.from(_messages);

      final apiMessages = historyMsgs.map((m) => {
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.content,
          }).toList();

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 512,
          'system': systemPrompt,
          'messages': apiMessages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final replyText =
            (data['content'] as List<dynamic>)[0]['text'] as String;

        final aiMsg = _ChatMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}_ai',
          content: replyText,
          isUser: false,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(aiMsg);
          _isTyping = false;
        });
      } else {
        _addErrorMessage('API hatası: ${response.statusCode}');
      }
    } catch (e) {
      _addErrorMessage('Bağlantı hatası. Lütfen tekrar deneyin.');
    }

    await _saveMessages();
    _scrollToBottom();
  }

  void _addErrorMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        content: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isTyping = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildChatBody(BuildContext context) {
    return Column(
      children: [
        _buildQuickQuestions(context),
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return _buildTypingIndicator(context);
                    }
                    return _buildMessageBubble(context, _messages[index]);
                  },
                ),
        ),
        _buildInputArea(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isDialog) {
      return Column(
        children: [
          // Title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                    color: colorScheme.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.psychology,
                      size: 18, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Beslenme Koçu',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('AI Asistan',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.normal)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  tooltip: 'Sohbeti Temizle',
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    if (!mounted) return;
                    await prefs.remove(_storageKey(context));
                    setState(() => _messages.clear());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.psychology,
                  size: 18, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Beslenme Koçu',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('AI Asistan',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Sohbeti Temizle',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              if (!mounted) return;
              await prefs.remove(_storageKey(context));
              setState(() => _messages.clear());
            },
          ),
        ],
      ),
      body: _buildChatBody(context),
    );
  }

  List<String> _buildDynamicQuestions(BuildContext context) {
    final hour = DateTime.now().hour;
    final nutrition = context.read<NutritionProvider>();
    final profile = context.read<ProfileProvider>().activeProfile;
    final today = nutrition.totalNutrition;
    final calorieGoal = context.read<ProfileProvider>().calorieGoal;
    final waterIntakeMl = nutrition.todayLog.waterIntakeMl;
    const waterGoalMl = 2500.0;

    final questions = <String>[];

    // 1. Sabah soruları (06:00 - 12:00)
    if (hour >= 6 && hour < 12) {
      questions.add('Sabah kahvaltısı için ne önerirsin?');
      questions.add('Bugün ne yemem gerekir?');
    }

    // 2. Akşam/Gece soruları (19:00 - 06:00)
    if (hour >= 19 || hour < 6) {
      questions.add('Uyku kalitemi artıracak besinler neler?');
      questions.add('Bugünkü beslenmeyi değerlendir');
    }

    // 3. Koşullu sorular
    if (nutrition.todayLog.exercises.isNotEmpty) {
      questions.add('Spor sonrası ne yemeliyim?');
    }

    if (waterIntakeMl < waterGoalMl * 0.8) {
      questions.add('Su tüketimimi artırmak için öneriler');
    }

    if (calorieGoal > 0 && today.calories < calorieGoal * 0.7) {
      questions.add('Kalori açığımı nasıl kapatabilirim?');
    }

    if (profile != null) {
      if (profile.proteinGoal > 0 && today.protein < profile.proteinGoal * 0.7) {
        questions.add('Protein hedefime nasıl ulaşırım?');
      }
      if (profile.carbGoal > 0 && today.carbohydrates < profile.carbGoal * 0.7) {
        questions.add('Karbonhidrat hedefime nasıl ulaşabilirim?');
      }
      if (profile.fatGoal > 0 && today.fat < profile.fatGoal * 0.7) {
        questions.add('Yağ tüketimimi nasıl düzenlemeliyim?');
      }
    }

    // 4. Her zaman göster
    questions.add('Bana sağlıklı bir tarif öner');
    questions.add('Bağışıklığımı güçlendirmek için ne yemeliyim?');

    return questions;
  }

  Widget _buildQuickQuestions(BuildContext context) {
    final questions = _buildDynamicQuestions(context);

    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: questions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(questions[index],
                style: const TextStyle(fontSize: 12)),
            onPressed: _isTyping ? null : () => _sendMessage(questions[index]),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final profile = context.watch<ProfileProvider>().activeProfile;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            profile != null
                ? 'Merhaba ${profile.name}! 👋'
                : 'Merhaba! 👋',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Beslenme hakkında soru sorabilirsin\nveya yukarıdaki hızlı sorulardan birini seç.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, _ChatMessage message) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.psychology,
                  size: 14, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF4CAF50)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(Icons.person,
                  size: 14, color: colorScheme.onSecondaryContainer),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.psychology,
                size: 14, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                _DotAnimation(delay: 0),
                const SizedBox(width: 4),
                _DotAnimation(delay: 200),
                const SizedBox(width: 4),
                _DotAnimation(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_isTyping,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Mesaj yaz...',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _isTyping
                ? null
                : () => _sendMessage(_textController.text),
            backgroundColor: _isTyping
                ? colorScheme.surfaceContainerHighest
                : const Color(0xFF4CAF50),
            elevation: 0,
            child: _isTyping
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DotAnimation extends StatefulWidget {
  final int delay;
  const _DotAnimation({required this.delay});

  @override
  State<_DotAnimation> createState() => _DotAnimationState();
}

class _DotAnimationState extends State<_DotAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: 0.3 + _anim.value * 0.7,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
