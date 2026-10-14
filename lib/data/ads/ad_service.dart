// google_mobile_ads / app_tracking_transparency は Android / iOS 専用のため、
// Web ビルドでは広告SDKに依存しないスタブ実装に切り替える。
export 'ad_service_mobile.dart'
    if (dart.library.js_interop) 'ad_service_web.dart';
