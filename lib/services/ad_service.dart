import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tripproject/services/app_data_provider.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isAdLoaded = false;
  bool _isAdShowing = false;
  Completer<bool>? _loadCompleter;
  Completer<void>? _dismissCompleter;

  /// Check if ads should be shown (false for subscribed users)
  bool get shouldShowAds => !AppDataProvider.instance.isSubscribed;

  // Ad Unit ID for Rewarded Interstitial
  static const String _rewardedInterstitialAdUnitId = 
      'ca-app-pub-6169991417418373/1165407814';

  // Test ad unit IDs (use these during development)
  static const String _testRewardedInterstitialAdUnitId = 
      'ca-app-pub-3940256099942544/5354046379';

  String get _adUnitId {
    // Use test ad unit ID in debug mode
    if (kDebugMode) {
      return _testRewardedInterstitialAdUnitId;
    }
    return _rewardedInterstitialAdUnitId;
  }

  /// Load a rewarded interstitial ad
  Future<bool> loadRewardedInterstitialAd() async {
    if (!shouldShowAds) {
      debugPrint('Ads disabled for subscribed users');
      return false;
    }
    if (_isAdLoaded || _isAdShowing) return true;

    _loadCompleter = Completer<bool>();

    await RewardedInterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _isAdLoaded = true;
          debugPrint('Rewarded interstitial ad loaded');
          _loadCompleter?.complete(true);

          // Set full screen content callback
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              _isAdShowing = true;
              debugPrint('Rewarded interstitial ad showed');
            },
            onAdDismissedFullScreenContent: (ad) {
              _isAdShowing = false;
              _isAdLoaded = false;
              ad.dispose();
              _rewardedInterstitialAd = null;
              _dismissCompleter?.complete();
              _dismissCompleter = null;
              debugPrint('Rewarded interstitial ad dismissed');
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isAdShowing = false;
              _isAdLoaded = false;
              ad.dispose();
              _rewardedInterstitialAd = null;
              debugPrint('Rewarded interstitial ad failed to show: ${error.message}');
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isAdLoaded = false;
          debugPrint('Rewarded interstitial ad failed to load: ${error.message}');
          _loadCompleter?.complete(false);
        },
      ),
    );

    return _loadCompleter?.future ?? Future.value(false);
  }

  /// Show the rewarded interstitial ad
  Future<bool> showRewardedInterstitialAd({
    Function(RewardItem)? onUserEarnedReward,
    VoidCallback? onAdDismissed,
  }) async {
    if (!shouldShowAds) {
      debugPrint('Ads disabled for subscribed users');
      return false;
    }
    if (_rewardedInterstitialAd == null || !_isAdLoaded) {
      debugPrint('Rewarded interstitial ad not loaded');
      return false;
    }

    if (_isAdShowing) {
      debugPrint('Ad is already showing');
      return false;
    }

    _dismissCompleter = Completer<void>();

    try {
      await _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          onUserEarnedReward?.call(reward);
          debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        },
      );
      // Wait for ad to be dismissed
      await _dismissCompleter?.future;
      onAdDismissed?.call();
      return true;
    } catch (e) {
      debugPrint('Error showing rewarded interstitial ad: $e');
      _dismissCompleter?.complete();
      _dismissCompleter = null;
      return false;
    }
  }

  /// Check if ad is loaded and ready to show
  bool get isAdLoaded => _isAdLoaded;

  /// Check if ad is currently showing
  bool get isAdShowing => _isAdShowing;

  /// Dispose the ad
  void dispose() {
    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
    _isAdLoaded = false;
    _isAdShowing = false;
  }
}
