import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/supabase_config.dart';
import 'data/ads/ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabaseの初期化(ローカルキャッシュからのセッション復元など)はawaitする
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(const ProviderScope(child: PokerChipsApp()));

  // 匿名ログインや広告SDKの初期化など、ネットワーク通信を伴う処理は
  // 初回描画(runApp)をブロックしないようにバックグラウンドで行う。
  unawaited(() async {
    if (Supabase.instance.client.auth.currentSession == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (e) {
        debugPrint('匿名ログイン失敗: $e');
      }
    }
  }());

  unawaited(AdService.initialize().then((_) => AdService.instance.preload()));
}
