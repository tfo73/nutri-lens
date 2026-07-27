import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoachMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  CoachMessage({
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

  factory CoachMessage.fromJson(Map<String, dynamic> json) => CoachMessage(
        id: json['id'] as String,
        content: json['content'] as String,
        isUser: json['isUser'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class CoachSession {
  final String archivedAt;
  final List<CoachMessage> messages;
  final bool isFavorite;
  final String? favoritedAt;

  CoachSession({
    required this.archivedAt,
    required this.messages,
    this.isFavorite = false,
    this.favoritedAt,
  });

  Map<String, dynamic> toJson() => {
        'archivedAt': archivedAt,
        'messages': messages.map((m) => m.toJson()).toList(),
        'isFavorite': isFavorite,
        'favoritedAt': favoritedAt,
      };

  factory CoachSession.fromJson(Map<String, dynamic> json) => CoachSession(
        archivedAt: json['archivedAt'] as String,
        messages: (json['messages'] as List<dynamic>)
            .map((e) => CoachMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        isFavorite: json['isFavorite'] as bool? ?? false,
        favoritedAt: json['favoritedAt'] as String?,
      );
}

class CoachProvider extends ChangeNotifier {
  final String profileId;
  List<CoachMessage> _currentMessages = [];
  List<CoachSession> _history = [];
  Timer? _midnightTimer;
  String? _prefilledMessage;

  String? get prefilledMessage => _prefilledMessage;

  void setPrefilledMessage(String? msg) {
    _prefilledMessage = msg;
    notifyListeners();
  }

  void clearPrefilledMessage() {
    _prefilledMessage = null;
    notifyListeners();
  }

  CoachProvider(this.profileId) {
    _load();
    _scheduleMidnightArchive();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  // Fires at next 00:00 to archive the day's session, then reschedules
  void _scheduleMidnightArchive() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      archiveSession();
      _scheduleMidnightArchive();
    });
  }

  List<CoachMessage> get currentMessages => List.unmodifiable(_currentMessages);
  List<CoachSession> get history => List.unmodifiable(_history);

  String get _messagesKey => 'coach_messages_$profileId';
  String get _historyKey => 'coach_history_$profileId';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load current session
    final rawMessages = prefs.getString(_messagesKey);
    if (rawMessages != null) {
      try {
        final list = jsonDecode(rawMessages) as List<dynamic>;
        _currentMessages = list.map((e) => CoachMessage.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // Load history
    final rawHistory = prefs.getString(_historyKey);
    if (rawHistory != null) {
      try {
        final list = jsonDecode(rawHistory) as List<dynamic>;
        _history = list.map((e) => CoachSession.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    // Archive stale session from a previous day
    _archiveIfPreviousDay();
    notifyListeners();

    // Cloud fetch
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        
        // Fetch active session
        final activeDoc = await userDoc.collection('coach').doc('active').get();
        if (activeDoc.exists) {
          final data = activeDoc.data()!;
          if (data['current'] != null) {
            _currentMessages = (data['current'] as List<dynamic>)
                .map((e) => CoachMessage.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }

        // Fetch history (individual sessions)
        final historyQuery = await userDoc.collection('coach_sessions').get();
        if (historyQuery.docs.isNotEmpty) {
          _history = historyQuery.docs
              .map((doc) => CoachSession.fromJson(doc.data()))
              .toList();
          _history.sort((a, b) => b.archivedAt.compareTo(a.archivedAt));
        }

        await _saveLocal();
        notifyListeners();
      } catch (e) {
        debugPrint('Coach cloud load error: $e');
      }
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_messagesKey, jsonEncode(_currentMessages.map((m) => m.toJson()).toList()));
    await prefs.setString(_historyKey, jsonEncode(_history.map((s) => s.toJson()).toList()));
  }

  Future<void> syncToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      // Sync active session
      await userDoc.collection('coach').doc('active').set({
        'current': _currentMessages.map((m) => m.toJson()).toList(),
        'lastSync': FieldValue.serverTimestamp(),
      });

      // Sync history (individual sessions)
      final batch = FirebaseFirestore.instance.batch();
      for (final session in _history) {
        // Use archivedAt (ISO string) as doc ID for day-by-day/timestamp uniqueness
        final docRef = userDoc.collection('coach_sessions').doc(session.archivedAt);
        batch.set(docRef, session.toJson());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Coach cloud sync error: $e');
    }
  }

  void addMessage(CoachMessage message) {
    _currentMessages.add(message);
    if (_currentMessages.length > 50) _currentMessages.removeAt(0);
    _saveLocal();
    
    // For real-time active session sync
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('coach')
          .doc('active')
          .set({
        'current': _currentMessages.map((m) => m.toJson()).toList(),
        'lastSync': FieldValue.serverTimestamp(),
      });
    }
    
    notifyListeners();
  }

  void updateMessage(String id, String newContent) {
    final index = _currentMessages.indexWhere((m) => m.id == id);
    if (index != -1) {
      final old = _currentMessages[index];
      _currentMessages[index] = CoachMessage(
        id: old.id,
        content: newContent,
        isUser: old.isUser,
        timestamp: old.timestamp,
      );
      _saveLocal();
      notifyListeners();
    }
  }

  void _archiveIfPreviousDay() {
    if (_currentMessages.isEmpty) return;
    final first = _currentMessages.first;
    final today = DateTime.now();
    if (first.timestamp.year != today.year ||
        first.timestamp.month != today.month ||
        first.timestamp.day != today.day) {
      archiveSession();
    }
  }

  void archiveSession() {
    if (_currentMessages.isEmpty) return;
    
    final session = CoachSession(
      archivedAt: DateTime.now().toIso8601String(),
      messages: List<CoachMessage>.from(_currentMessages),
    );
    
    _history.insert(0, session);
    if (_history.length > 20) _history.removeLast();
    
    _currentMessages = [];
    _saveLocal();
    syncToCloud();
    notifyListeners();
  }

  void toggleFavorite(String archivedAt) {
    final index = _history.indexWhere((s) => s.archivedAt == archivedAt);
    if (index != -1) {
      final s = _history[index];
      final isFav = !s.isFavorite;
      _history[index] = CoachSession(
        archivedAt: s.archivedAt,
        messages: s.messages,
        isFavorite: isFav,
        favoritedAt: isFav ? DateTime.now().toIso8601String() : null,
      );
      _saveLocal();
      syncToCloud();
      notifyListeners();
    }
  }

  void deleteSession(String archivedAt) {
    _history.removeWhere((s) => s.archivedAt == archivedAt);
    _saveLocal();
    syncToCloud();
    notifyListeners();
  }
}
