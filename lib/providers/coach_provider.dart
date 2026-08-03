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
  String? _selectedSessionId; // null represents active conversation, otherwise archivedAt of past session
  String? _prefilledMessage;

  String? get prefilledMessage => _prefilledMessage;
  String? get selectedSessionId => _selectedSessionId;

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
  }

  List<CoachMessage> get currentMessages {
    if (_selectedSessionId == null) {
      return List.unmodifiable(_currentMessages);
    }
    final session = _history.firstWhere(
      (s) => s.archivedAt == _selectedSessionId,
      orElse: () => CoachSession(archivedAt: '', messages: []),
    );
    return List.unmodifiable(session.messages);
  }

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
        final docRef = userDoc.collection('coach_sessions').doc(session.archivedAt);
        batch.set(docRef, session.toJson());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Coach cloud sync error: $e');
    }
  }

  void selectSession(String? archivedAt) {
    _selectedSessionId = archivedAt;
    notifyListeners();
  }

  void startNewSession() {
    if (_currentMessages.isNotEmpty) {
      final session = CoachSession(
        archivedAt: DateTime.now().toIso8601String(),
        messages: List<CoachMessage>.from(_currentMessages),
      );
      _history.insert(0, session);
      if (_history.length > 20) _history.removeLast();
      _currentMessages = [];
    }
    _selectedSessionId = null;
    _saveLocal();
    syncToCloud();
    notifyListeners();
  }

  void addMessage(CoachMessage message) {
    if (_selectedSessionId == null) {
      _currentMessages.add(message);
      if (_currentMessages.length > 50) _currentMessages.removeAt(0);
      
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
    } else {
      final index = _history.indexWhere((s) => s.archivedAt == _selectedSessionId);
      if (index != -1) {
        final session = _history[index];
        session.messages.add(message);
        if (session.messages.length > 50) session.messages.removeAt(0);
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.isAnonymous) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('coach_sessions')
              .doc(session.archivedAt)
              .set(session.toJson());
        }
      }
    }
    _saveLocal();
    notifyListeners();
  }

  void updateMessage(String id, String newContent) {
    List<CoachMessage> targetList;
    CoachSession? targetSession;
    
    if (_selectedSessionId == null) {
      targetList = _currentMessages;
    } else {
      final index = _history.indexWhere((s) => s.archivedAt == _selectedSessionId);
      if (index != -1) {
        targetSession = _history[index];
        targetList = targetSession.messages;
      } else {
        return;
      }
    }

    final index = targetList.indexWhere((m) => m.id == id);
    if (index != -1) {
      final old = targetList[index];
      targetList[index] = CoachMessage(
        id: old.id,
        content: newContent,
        isUser: old.isUser,
        timestamp: old.timestamp,
      );
      _saveLocal();
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        if (_selectedSessionId == null) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('coach')
              .doc('active')
              .set({
            'current': _currentMessages.map((m) => m.toJson()).toList(),
            'lastSync': FieldValue.serverTimestamp(),
          });
        } else if (targetSession != null) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('coach_sessions')
              .doc(targetSession.archivedAt)
              .set(targetSession.toJson());
        }
      }
      notifyListeners();
    }
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
    if (_selectedSessionId == archivedAt) {
      _selectedSessionId = null;
    }
    _saveLocal();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('coach_sessions')
          .doc(archivedAt)
          .delete()
          .catchError((e) => debugPrint('Error deleting session from cloud: $e'));
    }

    syncToCloud();
    notifyListeners();
  }
}
