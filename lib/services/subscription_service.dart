import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/notification_log_service.dart';

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  static const String productId = 'wejhaty_premium';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _premiumProduct;
  bool _isAvailable = false;
  List<PurchaseDetails> _purchases = [];

  /// Completes with the outcome of the store purchase flow that is currently
  /// open (true = purchased/restored, false = error/cancelled). When no
  /// store flow is running (dev fallback / web), [subscribe] resolves the
  /// result by itself and this is never awaited.
  Completer<bool>? _pendingPurchase;

  /// Result of the purchase flow launched by the last [subscribe] call.
  Future<bool> get pendingPurchaseResult =>
      _pendingPurchase?.future ?? Future<bool>.value(true);

  ProductDetails? get premiumProduct => _premiumProduct;
  bool get isAvailable => _isAvailable;

  Future<void> init() async {
    if (kIsWeb) return;

    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) return;

      final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          debugPrint('SubscriptionService error: $error');
        },
      );

      await queryProducts();
      await verifySubscriptionStatus();
    } catch (e) {
      debugPrint('SubscriptionService init exception: $e');
    }
  }

  Future<void> queryProducts() async {
    if (!_isAvailable) return;

    try {
      final Set<String> ids = {productId};
      final ProductDetailsResponse response = await _iap.queryProductDetails(ids);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }

      if (response.productDetails.isNotEmpty) {
        _premiumProduct = response.productDetails.firstWhere(
          (p) => p.id == productId,
          orElse: () => response.productDetails.first,
        );
      }
    } catch (e) {
      debugPrint('SubscriptionService queryProducts failed: $e');
    }
  }

  Future<bool> subscribe() async {
    if (_premiumProduct != null && _isAvailable) {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: _premiumProduct!);
      try {
        // The store payment sheet is opening — its real outcome arrives
        // through [pendingPurchaseResult] once the purchase stream fires.
        _pendingPurchase = Completer<bool>();
        final launched = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
        if (!launched) {
          // Store refused to open — treat like the direct fallback.
          _pendingPurchase = null;
          debugPrint('Store refused to open billing sheet');
          return false;
        }
        return true;
      } catch (e) {
        _pendingPurchase = null;
        debugPrint('Subscribe failed: $e');
        return false;
      }
    }

    // Billing not available - don't auto-subscribe
    debugPrint('Billing not available: isAvailable=$_isAvailable, product=$_premiumProduct');
    return false;
  }

  Future<void> restorePurchases() async {
    if (_isAvailable) {
      try {
        await _iap.restorePurchases();
      } catch (e) {
        debugPrint('Restore failed: $e');
      }
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      // Update cached purchases
      final existingIndex = _purchases.indexWhere((p) => p.purchaseID == purchaseDetails.purchaseID);
      if (existingIndex >= 0) {
        _purchases[existingIndex] = purchaseDetails;
      } else {
        _purchases.add(purchaseDetails);
      }

      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Purchase in progress — keep waiting.
        continue;
      }

      // Resolve whoever is awaiting the store flow outcome.
      final completer = _pendingPurchase;
      _pendingPurchase = null;

      if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchaseDetails.error}');
        NotificationLogService.instance.logSubscriptionFailed(
          purchaseDetails.error?.message ?? 'Unknown error',
        );
        completer?.complete(false);
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        // User cancelled during purchase flow
        NotificationLogService.instance.logSubscriptionFailed(
          'Purchase was cancelled by user',
        );
        completer?.complete(false);
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        AppDataProvider.instance.setSubscribed(true);
        final price = _premiumProduct?.price;
        NotificationLogService.instance.logSubscriptionSuccess(price: price);
        completer?.complete(true);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _iap.completePurchase(purchaseDetails);
      }
    }

    // After processing updates, verify overall subscription status
    _verifySubscriptionFromPurchases();
  }

  /// Verifies subscription status by querying Google Play for current purchases
  Future<void> verifySubscriptionStatus() async {
    if (!_isAvailable) return;

    try {
      await _iap.restorePurchases();
      // The restorePurchases call will trigger _onPurchaseUpdate with current purchases
    } catch (e) {
      debugPrint('Failed to verify subscription status: $e');
    }
  }

  /// Checks cached purchases and updates subscription status accordingly
  void _verifySubscriptionFromPurchases() {
    if (_purchases.isEmpty) {
      // No purchases found, user should be on free tier
      if (AppDataProvider.instance.isSubscribed) {
        AppDataProvider.instance.setSubscribed(false);
      }
      return;
    }

    // Check if there's an active purchase for our product
    final hasActivePurchase = _purchases.any((purchase) {
      if (purchase.productID != productId) return false;
      
      // Check purchase status
      if (purchase.status == PurchaseStatus.purchased || 
          purchase.status == PurchaseStatus.restored) {
        return true;
      }
      
      return false;
    });

    // Update local state based on actual purchase status
    if (hasActivePurchase && !AppDataProvider.instance.isSubscribed) {
      AppDataProvider.instance.setSubscribed(true);
    } else if (!hasActivePurchase && AppDataProvider.instance.isSubscribed) {
      // Subscription cancelled or expired in Google Play
      AppDataProvider.instance.setSubscribed(false);
      NotificationLogService.instance.logSubscriptionCancelled();
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
