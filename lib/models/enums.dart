/// ハンド内の進行フェーズ。lobby=部屋作成直後、interHand=ハンド終了後の待機
/// (借金・ハート回復広告が可能)。
enum GamePhase { lobby, preflop, flop, turn, river, showdown, interHand }

enum ActionType { fold, check, call, raise, allIn }

enum PlayerStatus { active, folded, allIn, waitingAd, kicked }
