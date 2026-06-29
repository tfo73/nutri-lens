import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PromoCodeService {
  PromoCodeService._();
  static final instance = PromoCodeService._();

  Future<Map<String, dynamic>?> validatePromoCode(String code) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('promo_codes')
          .doc(code.toUpperCase().trim())
          .get();

      if (!doc.exists) return null;
      final data = doc.data()!;
      
      if (data['isActive'] == false) return null;

      final maxUses = data['maxUses'] as int?;
      final usedCount = data['usedCount'] as int? ?? 0;
      
      if (maxUses != null && usedCount >= maxUses) return null;

      return data;
    } catch (e) {
      debugPrint('Promo code error: $e');
      return null;
    }
  }

  Future<bool> markCodeAsUsed(String code) async {
    try {
      final db = FirebaseFirestore.instance;
      final codeRef = db.collection('promo_codes').doc(code.toUpperCase().trim());
      
      await db.runTransaction((tx) async {
        final codeDoc = await tx.get(codeRef);
        if (!codeDoc.exists) throw Exception('Code not found');
        
        final usedCount = codeDoc.data()?['usedCount'] as int? ?? 0;
        tx.update(codeRef, {'usedCount': usedCount + 1});
      });
      return true;
    } catch (e) {
      debugPrint('Mark code used error: $e');
      return false;
    }
  }

  Future<bool> applyDurationCode(String code, int durationDays) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final db = FirebaseFirestore.instance;
      
      await db.runTransaction((tx) async {
        final codeRef = db.collection('promo_codes').doc(code.toUpperCase().trim());
        final codeDoc = await tx.get(codeRef);
        if (!codeDoc.exists) throw Exception('Code not found');
        
        final usedCount = codeDoc.data()?['usedCount'] as int? ?? 0;
        tx.update(codeRef, {'usedCount': usedCount + 1});

        final userRef = db.collection('users').doc(user.uid);
        
        // Grant premium
        final expiration = DateTime.now().add(Duration(days: durationDays));
        tx.set(userRef, {
          'premium': {
            'isPremium': true,
            'expirationDate': expiration.toIso8601String(),
            'grantedByPromoCode': code,
          }
        }, SetOptions(merge: true));
      });
      return true;
    } catch (e) {
      debugPrint('Error applying code: $e');
      return false;
    }
  }
}
