class GameConstants {
  GameConstants._();

  static const int initialStack = 10000;
  static const int borrowUnit = 10000;
  static const int maxHearts = 5;
  static const Duration adWaitTimeout = Duration(seconds: 30);
  static const int minPlayers = 2;
  static const int maxPlayers = 6;

  /// ルーム作成時のデフォルト設定値。ホストはロビー画面から変更できる
  /// (詳細は[PokerChipEngine.updateSettings]参照)。
  static const int defaultSmallBlind = 50;
  static const int defaultBigBlind = 100;
  static const int defaultAnte = 0;

  /// 設定画面で入力できる各値の上限/下限。極端な設定による事故を防ぐための目安。
  static const int maxBlindAmount = 100000;
  static const int maxAnteAmount = 100000;
  static const int minStartingStack = 100;
  static const int maxStartingStack = 1000000;

  /// デモ用の「あいことば」。本番運用時に差し替え可能。
  static const String secretWord = '20060527';
}
