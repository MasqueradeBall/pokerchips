import '../models/enums.dart';
import 'room_snapshot.dart';

/// ルーム/ゲーム進行を扱う抽象interface。
///
/// [SupabaseRoomRepository](supabase/supabase_room_repository.dart) が本番の
/// オンライン対戦実装。[LocalRoomRepository](local/local_room_repository.dart) は
/// 1台のデバイスでホスト+Botと対戦するオフラインデモ実装で、コードは残しているが
/// 現在Home画面からは直接使用していない。
abstract class RoomRepository {
  /// 現在のゲーム状態を配信するStream。
  Stream<RoomSnapshot> watch();

  /// ルームを作成する。戻り値は自分自身(ホスト)のplayerId。
  Future<String> createRoom({required String hostName});

  /// ルームIDを指定して既存のルームに参加する。戻り値は自分自身のplayerId。
  Future<String> joinRoom({required String playerName, required String roomCode});

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

  /// ブラインド/アンティ/初期チップ枚数を変更する(ロビー中のホストのみ想定)。
  void updateSettings({
    int? smallBlind,
    int? bigBlind,
    int? ante,
    int? startingStack,
  });

  /// ショーダウンで勝者を選び、ポットを分配する。
  void awardPot(List<String> winnerIds);

  /// 動画リワード広告の視聴が完了した際に呼ぶ。ハートを最大まで回復する。
  void resolveAdWatched(String playerId);

  void dispose();
}
