import 'package:flutter/foundation.dart';

// IAP product IDs — update when configuring App Store / Play Store
const kProductMonthly = 'nutrilens_premium_monthly';
const kProductYearly = 'nutrilens_premium_yearly';

enum PurchaseResult { success, cancelled, error }

/// Skeleton IAP service. Replace the body of [purchase] with a real
/// `in_app_purchase` (or RevenueCat) call when the package is added.
class PurchaseService {
  PurchaseService._();
  static final instance = PurchaseService._();

  /// Attempt to purchase [productId].
  /// Returns [PurchaseResult.success] on verified purchase.
  Future<PurchaseResult> purchase(String productId) async {
    // TODO: integrate in_app_purchase or purchases_flutter (RevenueCat)
    // Example (in_app_purchase):
    //   final available = await InAppPurchase.instance.isAvailable();
    //   if (!available) return PurchaseResult.error;
    //   final details = await _queryProduct(productId);
    //   await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
    //   // listen to purchaseStream for result…
    debugPrint('[PurchaseService] purchase($productId) — IAP not yet wired');
    return PurchaseResult.error;
  }

  /// Restore previous purchases and return whether premium is active.
  Future<bool> restorePurchases() async {
    // TODO: call InAppPurchase.instance.restorePurchases() and verify receipts
    debugPrint('[PurchaseService] restorePurchases() — IAP not yet wired');
    return false;
  }
}
