import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/services/app_data_provider.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  // Real Ad Unit ID provided by user
  static const String _adUnitId = 'ca-app-pub-6169991417418373/8188686599';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadAd();
    }
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      factoryId: 'adFactoryExample', // This might need native side setup if using custom factory
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAd failed to load: $error');
          ad.dispose();
        },
      ),
      // Using Small template for better integration into the home list
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Colors.transparent,
        cornerRadius: AppTheme.radiusMd,
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || AppDataProvider.instance.isSubscribed) return const SizedBox.shrink();

    if (_isLoaded && _nativeAd != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 90, // Height for 'small' template
        width: double.infinity,
        child: AdWidget(ad: _nativeAd!),
      );
    }

    return const SizedBox.shrink();
  }
}
