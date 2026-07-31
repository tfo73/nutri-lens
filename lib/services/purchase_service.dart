import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';


// IAP product IDs — update when configuring App Store / Play Store
const kProductMonthly = 'premium_monthly';
const kProductYearly = 'premium_yearly';
const kProductLifetime = 'premium_lifetime';

enum PurchaseResult { success, cancelled, error }

/// In-App Purchases service integration using `in_app_purchase` package.
class PurchaseService {
  PurchaseService._() {
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        debugPrint('[PurchaseService] Stream error: $error');
        _completePurchaseFlow(PurchaseResult.error);
      },
    );
  }

  static final instance = PurchaseService._();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  Completer<PurchaseResult>? _purchaseCompleter;

  /// Attempt to purchase [productId].
  /// Returns [PurchaseResult.success] on verified purchase.
  Future<PurchaseResult> purchase(String productId) async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      debugPrint('[PurchaseService] Store not available');
      return PurchaseResult.error;
    }

    // Query product details from Google Play / App Store
    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails({productId});
    if (response.notFoundIDs.contains(productId) || response.productDetails.isEmpty) {
      debugPrint('[PurchaseService] Product not found: $productId');
      return PurchaseResult.error;
    }

    final ProductDetails productDetails = response.productDetails.first;
    _purchaseCompleter = Completer<PurchaseResult>();

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('[PurchaseService] Error initiating purchase: $e');
      _purchaseCompleter = null;
      return PurchaseResult.error;
    }

    return _purchaseCompleter!.future;
  }

  /// Restore previous purchases and return whether premium is active.
  bool _isRestoring = false;
  final List<PurchaseDetails> _restoredPurchases = [];

  /// Restore previous purchases and return whether premium is active.
  Future<bool> restorePurchases() async {
    try {
      _isRestoring = true;
      _restoredPurchases.clear();
      await InAppPurchase.instance.restorePurchases();
      // Wait a short time to allow stream to handle it
      await Future.delayed(const Duration(milliseconds: 1500));
      _isRestoring = false;
      return _restoredPurchases.isNotEmpty;
    } catch (e) {
      debugPrint('[PurchaseService] Error restoring purchases: $e');
      _isRestoring = false;
      return false;
    }
  }

  /// Query past purchases silently to check active status.
  Future<List<PurchaseDetails>> queryActivePurchasesSilently() async {
    try {
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        debugPrint('[PurchaseService] Billing client not available');
        throw Exception('Billing client not available');
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidAddition = InAppPurchase.instance
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        final response = await androidAddition.queryPastPurchases();
        if (response.error != null) {
          debugPrint('[PurchaseService] Error querying past purchases: ${response.error!.message}');
          throw Exception(response.error!.message);
        }
        return response.pastPurchases;
      } else {
        _isRestoring = true;
        _restoredPurchases.clear();

        await InAppPurchase.instance.restorePurchases();

        // Wait a short time for the stream to receive the events
        await Future.delayed(const Duration(milliseconds: 1500));

        _isRestoring = false;
        return List.from(_restoredPurchases);
      }
    } catch (e) {
      debugPrint('[PurchaseService] Error querying active purchases: $e');
      _isRestoring = false;
      rethrow;
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('[PurchaseService] Purchase pending...');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('[PurchaseService] Purchase error: ${purchaseDetails.error}');
        _completePurchaseFlow(PurchaseResult.error);
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        debugPrint('[PurchaseService] Purchase cancelled by user');
        _completePurchaseFlow(PurchaseResult.cancelled);
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        debugPrint('[PurchaseService] Purchase successful or restored: ${purchaseDetails.productID}');
        if (_isRestoring) {
          _restoredPurchases.add(purchaseDetails);
        }
        _completePurchaseFlow(PurchaseResult.success);
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void _completePurchaseFlow(PurchaseResult result) {
    if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
      _purchaseCompleter!.complete(result);
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
