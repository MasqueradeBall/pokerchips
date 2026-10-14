import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// 動画リワード広告(ハート回復)をラップするサービス。
/// 現在はGoogle公式のテスト広告ユニットIDを使用している。
/// 本番運用時は [_rewardedAdUnitId] をAdMobで取得した本番IDに差し替えること。
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  static Future<void> initialize() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          // ATTのダイアログが正しく表示されるよう、UI描画後に少し待つ
          await Future.delayed(const Duration(milliseconds: 500));
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      } catch (e) {
        debugPrint('ATT Request Error: $e');
      }
    }
    await MobileAds.instance.initialize();
  }

  static String get _rewardedAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ca-app-pub-3940256099942544/5224354917';
      case TargetPlatform.iOS:
        return 'ca-app-pub-1834741602239899/5962022663';
      default:
        return 'ca-app-pub-3940256099942544/5224354917';
    }
  }

  RewardedAd? _rewardedAd;
  bool _loading = false;

  void preload() {
    if (_rewardedAd != null || _loading) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) {
          _loading = false;
        },
      ),
    );
  }

  /// 広告を表示し、視聴が完了(報酬獲得)したら true を返す。
  Future<bool> showRewardedAd() async {
    final ad = _rewardedAd;
    if (ad == null) {
      preload();
      return false;
    }
    _rewardedAd = null;

    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preload();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preload();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        if (!completer.isCompleted) completer.complete(true);
      },
    );
    return completer.future;
  }
}
