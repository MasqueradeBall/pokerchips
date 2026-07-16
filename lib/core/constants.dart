class GameConstants {
  GameConstants._();

  static const int initialStack = 10000;
  static const int borrowUnit = 10000;
  static const int maxHearts = 5;
  static const Duration adWaitTimeout = Duration(seconds: 30);
  static const int minPlayers = 2;
  static const int maxPlayers = 6;

  /// デモ用の「あいことば」。本番運用時に差し替え可能。
  static const String secretWord = 'POKERVIP';
}
