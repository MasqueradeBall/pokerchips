import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/local_room_repository.dart';
import '../data/room_repository.dart';
import '../data/supabase/supabase_room_repository.dart';

/// trueの間は[roomRepositoryProvider]がオフラインBot対戦デモ([LocalRoomRepository])を、
/// falseの間は本番のSupabase版(オンライン対戦)を返す。
final demoModeProvider = StateProvider<bool>((ref) => false);

/// アプリ全体で1つのRoomRepositoryを共有する。
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  final isDemo = ref.watch(demoModeProvider);
  final repository = isDemo ? LocalRoomRepository() : SupabaseRoomRepository();
  ref.onDispose(repository.dispose);
  return repository;
});
