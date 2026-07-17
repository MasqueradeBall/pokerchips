import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/supabase_config.dart';
import 'data/ads/ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  if (Supabase.instance.client.auth.currentSession == null) {
    await Supabase.instance.client.auth.signInAnonymously();
  }
  runApp(const ProviderScope(child: PokerChipsApp()));

  // 広告SDKの初期化は数秒かかることがあり、初回描画をブロックしないよう
  // runApp後にバックグラウンドで行う(ハートが尽きるまで広告は使われない)。
  unawaited(AdService.initialize().then((_) => AdService.instance.preload()));
}
