import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdService {
  static const _kAnonUidKey = 'device_anon_uid';
  static DeviceIdService? _instance;
  static DeviceIdService get instance => _instance ??= DeviceIdService._();
  DeviceIdService._();

  // Returns the current Firebase UID (anonymous or real).
  // Signs in anonymously on first call if no user is present.
  Future<String> ensureFirebaseUser() async {
    if (Platform.isWindows || Platform.isLinux) return 'local-dev';

    final auth = FirebaseAuth.instance;

    if (auth.currentUser != null) {
      return auth.currentUser!.uid;
    }

    // Try to restore from prefs (same app session across hot restarts)
    final prefs = await SharedPreferences.getInstance();
    final storedUid = prefs.getString(_kAnonUidKey);

    // Sign in anonymously — Firebase reuses the account on same device
    // as long as the app data is not cleared.
    try {
      final cred = await auth.signInAnonymously();
      final uid = cred.user!.uid;
      await prefs.setString(_kAnonUidKey, uid);
      await _recordDeviceFingerprint(uid, storedUid);
      return uid;
    } catch (_) {
      // Fallback: return stored UID if offline
      return storedUid ?? 'anon-offline';
    }
  }

  // When user creates an email/password account, link the anonymous Firebase
  // user to the new credentials so all data under the anonymous UID is preserved.
  Future<UserCredential?> linkAnonymousToEmail({
    required String email,
    required String password,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.isAnonymous) return null;

    final credential = EmailAuthProvider.credential(email: email, password: password);
    return await user.linkWithCredential(credential);
  }

  // When user signs in with Google and was previously anonymous, attempt to
  // link; on credential-already-in-use we migrate onboarding data to the
  // existing Google account instead.
  Future<void> migrateAnonDataToUser(String targetUid) async {
    final anonUid = FirebaseAuth.instance.currentUser?.uid;
    if (anonUid == null || anonUid == targetUid) return;

    try {
      final db = FirebaseFirestore.instance;
      final anonDoc = await db.collection('users').doc(anonUid).get();
      if (!anonDoc.exists) return;

      // Copy onboarding answers to the new account if not already present
      final targetDoc = await db.collection('users').doc(targetUid).get();
      final targetHasOnboarding =
          (targetDoc.data()?['onboarding']?['completed'] ?? false) as bool;

      if (!targetHasOnboarding && anonDoc.data()?['onboarding'] != null) {
        await db.collection('users').doc(targetUid).set(
          {'onboarding': anonDoc.data()!['onboarding']},
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  Future<void> savePremiumStatus({required bool isPremium, required String planId}) async {
    if (Platform.isWindows || Platform.isLinux) return;
    try {
      final uid = await ensureFirebaseUser();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'premium': {
          'active': isPremium,
          'planId': planId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<bool> getPremiumStatus() async {
    if (Platform.isWindows || Platform.isLinux) return false;
    try {
      final uid = await ensureFirebaseUser();
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return (doc.data()?['premium']?['active'] ?? false) as bool;
    } catch (_) {
      return false;
    }
  }

  Future<void> _recordDeviceFingerprint(String uid, String? previousAnonUid) async {
    try {
      final plugin = DeviceInfoPlugin();
      final Map<String, dynamic> fp = {};

      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        fp['platform'] = 'android';
        fp['androidId'] = info.id;
        fp['model'] = info.model;
        fp['brand'] = info.brand;
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        fp['platform'] = 'ios';
        fp['identifierForVendor'] = info.identifierForVendor;
        fp['model'] = info.model;
        fp['systemVersion'] = info.systemVersion;
      }

      final data = {
        'fingerprint': fp,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (previousAnonUid != null && previousAnonUid != uid) {
        data['previousAnonUid'] = previousAnonUid as Object;
      }

      await FirebaseFirestore.instance
          .collection('devices')
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (_) {}
  }
}
