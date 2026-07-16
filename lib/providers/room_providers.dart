import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/room_snapshot.dart';
import 'repository_providers.dart';

final roomSnapshotProvider = StreamProvider<RoomSnapshot>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return repository.watch();
});
