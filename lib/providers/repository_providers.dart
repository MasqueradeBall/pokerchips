import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/room_repository.dart';
import '../data/supabase/supabase_room_repository.dart';

/// アプリ全体で1つのRoomRepositoryを共有する。
/// 本番はSupabase版(オンライン対戦)。ローカルBot対戦デモに戻したい場合は
/// `LocalRoomRepository()`(data/local/local_room_repository.dart)に差し替えるだけで良い。
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  final repository = SupabaseRoomRepository();
  ref.onDispose(repository.dispose);
  return repository;
});
