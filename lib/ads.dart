import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// true = إعلانات تجريبية من Google (آمنة للتجربة).
// بعد ما تحط الأرقام الحقيقية تحت، غيّرها لـ false.
const bool kUseTestAds = true;
const String kRealBanner = '';
const String kRealInterstitial = '';

bool get _useReal => Platform.isAndroid && !kUseTestAds;

String _bannerId() {
  if (_useReal && kRealBanner.isNotEmpty) return kRealBanner;
  return Platform.isAndroid ? 'ca-app-pub-3940256099942544/6300978111' : 'ca-app-pub-3940256099942544/2934735716';
}

String _interId() {
  if (_useReal && kRealInterstitial.isNotEmpty) return kRealInterstitial;
  return Platform.isAndroid ? 'ca-app-pub-3940256099942544/1033173712' : 'ca-app-pub-3940256099942544/4411468910';
}

class Ads {
  static bool _started = false;
  static bool ready = false;
  static final ValueNotifier<bool> readyNotifier = ValueNotifier(false);
  static InterstitialAd? _inter;
  static DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> init() async {
    if (_started) return;
    _started = true;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          ConsentForm.loadAndShowConsentFormIfRequired((err) {
            if (!done.isCompleted) done.complete();
          });
        },
        (FormError e) {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
      if (await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.initialize();
        ready = true;
        readyNotifier.value = true;
        _loadInterstitial();
      }
    } catch (_) {}
  }

  static void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _inter = ad,
        onAdFailedToLoad: (e) => _inter = null,
      ),
    );
  }

  static void maybeShowInterstitial() {
    final ad = _inter;
    if (!ready || ad == null) return;
    if (DateTime.now().difference(_lastShown) < const Duration(minutes: 3)) return;
    _inter = null;
    _lastShown = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }
}

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Ads.readyNotifier.addListener(_try);
    _try();
  }

  void _try() {
    if (_ad != null || !Ads.ready) return;
    _ad = BannerAd(
      adUnitId: _bannerId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, e) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    Ads.readyNotifier.removeListener(_try);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
