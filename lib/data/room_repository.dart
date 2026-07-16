import '../models/enums.dart';
import 'room_snapshot.dart';

/// ルーム/ゲーム進行を扱う抽象interface。
///
/// 現在は [LocalRoomRepository](local/local_room_repository.dart) のみが実装されており、
/// 1台のデバイスでホスト+Bot対戦するデモ/オフラインモードとして動作する。
/// 将来Supabase Realtimeで本当のオンライン対戦に対応する際は、この interface を
/// 実装する `SupabaseRoomRepository` を追加し、Riverpodのprovider定義を差し替えるだけで良い。
abstract class RoomRepository {
  /// 現在のゲーム状態を配信するStream。
  Stream<RoomSnapshot> watch();

  /// ルームを作成し、host + bot(totalPlayers-1体)でハンドを開始する。
  /// 戻り値は自分自身(ホスト)のplayerId。
  Future<String> createRoom({required String hostName, required int totalPlayers});

  /// fold/check/call/raise/allIn を送信する。
  void performAction(String playerId, ActionType action, {int amount = 0});

  /// 直前の1手のみを取り消す。
  void undo();

  /// プレイヤーをキックする(ホストのみ想定)。賭けていたチップはデッドマネーとしてポットに残る。
  void kickPlayer(String playerId);

  /// ハンド間の待機中のみ有効な借金。
  void borrowChips(String playerId);

  /// あいことばを適用する。
  void applySecretWord(String playerId, String word);

  /// 次のハンドを開始する(待機中のみ)。
  void startNextHand();

  /// ショーダウンで勝者を選び、ポットを分配する。
  void awardPot(List<String> winnerIds);

  /// 動画リワード広告の視聴が完了した際に呼ぶ。ハートを最大まで回復する。
  void resolveAdWatched(String playerId);

  void dispose();
}
