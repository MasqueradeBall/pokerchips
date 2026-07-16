import 'enums.dart';

class Player {
  Player({
    required this.id,
    required this.name,
    required this.chips,
    this.currentBet = 0,
    this.handContribution = 0,
    this.hearts = 5,
    this.isAdFree = false,
    this.borrowCount = 0,
    this.status = PlayerStatus.active,
    this.isBot = false,
    this.isHost = false,
  });

  final String id;
  final String name;
  final int chips;
  /// このストリート(preflop/flop/turn/river)で既に賭けた額。ラウンド完了判定に使う。
  final int currentBet;
  /// このハンドを通じて賭けた累計額。まだポットが分配されていない間も
  /// 「自分の資産」として純資産計算に含めるためのフィールド。
  final int handContribution;
  final int hearts;
  final bool isAdFree;
  final int borrowCount;
  final PlayerStatus status;
  final bool isBot;
  final bool isHost;

  /// 純資産 = 手持ちチップ + このハンドで賭けた分(まだ自分のものと数える) - 借金額
  int get netAsset => chips + handContribution - borrowCount * 10000;

  bool get isInHand =>
      status == PlayerStatus.active || status == PlayerStatus.allIn;

  Player copyWith({
    String? name,
    int? chips,
    int? currentBet,
    int? handContribution,
    int? hearts,
    bool? isAdFree,
    int? borrowCount,
    PlayerStatus? status,
    bool? isBot,
    bool? isHost,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      chips: chips ?? this.chips,
      currentBet: currentBet ?? this.currentBet,
      handContribution: handContribution ?? this.handContribution,
      hearts: hearts ?? this.hearts,
      isAdFree: isAdFree ?? this.isAdFree,
      borrowCount: borrowCount ?? this.borrowCount,
      status: status ?? this.status,
      isBot: isBot ?? this.isBot,
      isHost: isHost ?? this.isHost,
    );
  }
}
