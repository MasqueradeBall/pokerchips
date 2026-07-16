import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/local_room_repository.dart';
import '../data/room_repository.dart';

/// アプリ全体で1つのRoomRepositoryを共有する。
/// オンライン対戦対応時は実装をSupabase版に差し替えるだけで済む。
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  final repository = LocalRoomRepository();
  ref.onDispose(repository.dispose);
  return repository;
});
