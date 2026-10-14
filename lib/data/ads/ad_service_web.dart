/// Web 版の [AdService]。
/// google_mobile_ads は Web 非対応のため広告は表示せず、
/// 動画リワード広告の視聴は常に完了扱い(ハート回復)とする。
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  static Future<void> initialize() async {}

  void preload() {}

  /// 広告を表示せず、視聴完了(報酬獲得)として true を返す。
  Future<bool> showRewardedAd() async => true;
}
