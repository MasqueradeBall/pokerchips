# Poker Chips (ポーカーチップアプリ)

物理トランプ + アプリでチップ計算とハンド進行を管理するポーカー補助アプリ。
設計書: `pokerchips_design.html`

## 現在の状態: ローカルデモ(Bot対戦)モード

Supabase(オンライン対戦バックエンド)は未接続。今は **1台のデバイスでホスト+Bot(簡易AI)と対戦するデモ/オフラインモード** として、以下の機能をすべて実装・動作確認済み:

- ルーム作成(人数2〜6人選択、あいことば入力)
- Fold / Check / Call / Raise(スライダー+プリセット) / All-in
- ラウンド進行(全員のベットが揃うと自動でストリート進行、システムメッセージ表示)
- オールイン全画面エフェクト
- Undo(直前の1手のみ、host画面で最新アクションのプレイヤーバッジに×ボタン表示)
- ホストによるキック(長押し)+ デッドマネー(賭けていたチップはポットに残る)
- ハート(最大5、1ハンドごとに1減少、あいことばで減少しないフラグ)
- ハートが0になったプレイヤーの動画リワード広告視聴(Googleテスト広告ID)+ 他プレイヤーのロック表示 + 30秒タイムアウト強制キック
- ハンド間待機中のみ可能な+10,000借入、純資産(資産 = 手持ちチップ+今ハンドの賭け金合計−借金額)は常に「参加人数×10,000」を維持
- ショーダウンでの勝者選択(ホストのみ)とポット分配

「参加する(ルームID入力)」ボタンは残していますが、押すと案内メッセージが出るだけです(オンライン対戦は次フェーズ)。

## 動かし方

```bash
flutter pub get
flutter test          # ポーカーロジックのユニットテスト
flutter emulators --launch Pixel_9
flutter run           # Androidエミュレータ/実機で起動
```

`google_mobile_ads` は Android / iOS のみ対応のため、Windows desktop / Web では実行できません。

## アーキテクチャ

- `lib/models`, `lib/domain/poker_chip_engine.dart` — 純粋なゲームロジック(ベット計算・フェーズ進行・Undo・キック・借金・ハートなど)。`GameState`を受け取り新しい`GameState`を返す副作用のない関数群で、`test/poker_chip_engine_test.dart`でユニットテスト済み。
- `lib/data/room_repository.dart` — バックエンドを差し替え可能にする抽象interface。現在は `lib/data/local/local_room_repository.dart` (Bot対戦のインメモリ実装)のみ存在。
- `lib/providers` — Riverpodのprovider/controller。
- `lib/screens` — Home / Play / Waiting(ハンド間待機)画面。

## 既知の簡略化・制限

- Undoはベットアクション(fold/check/call/raise/allIn)のみが対象。キック・借金・あいことば・広告視聴・ハンド開始・ポット分配は取り消せない(仕様上そうあるべきという判断)。
- 勝者判定(ショーダウン)は物理カードで行われるため、アプリ側では**ホストが勝者を手動選択**する画面を追加している(設計書に明記はないが、チップ分配に必須のため)。
- サイドポット(複数プレイヤーが異なる額でオールインした場合の分割)は未対応。ポットは単一。
- ローカルモードでは実際のターン強制(サーバー側の「本人の手番か」検証)は行っていない。Supabase版では検証を追加すること。

## Supabase接続(オンライン対戦)を追加する手順

1. https://supabase.com でプロジェクトを作成し、URL / anon key を取得
2. SQL Editorで `supabase/schema.sql` を実行(rooms/players/action_logsテーブル + RLSポリシー + Realtime配信設定)
3. `supabase_flutter` パッケージを追加し、`main.dart`で`Supabase.initialize(url: ..., anonKey: ...)`
4. `lib/data/room_repository.dart` を実装する `SupabaseRoomRepository` を追加し、`lib/providers/repository_providers.dart` の生成先を差し替える
5. 認証は匿名サインイン(`Supabase.instance.client.auth.signInAnonymously()`)を推奨(schema.sqlのRLSがこれを前提にしている)

## AdMob本番広告IDへの差し替え

現在はGoogle公式のテスト広告IDを使用している。本番配信前に以下を差し替えること:

| 用途 | ファイル | 現在値(テスト) |
|---|---|---|
| Android App ID | `android/app/src/main/AndroidManifest.xml` | `ca-app-pub-3940256099942544~3347511713` |
| iOS App ID | `ios/Runner/Info.plist` (`GADApplicationIdentifier`) | `ca-app-pub-3940256099942544~1458002511` |
| Android リワード広告ユニットID | `lib/data/ads/ad_service.dart` | `ca-app-pub-3940256099942544/5224354917` |
| iOS リワード広告ユニットID | `lib/data/ads/ad_service.dart` | `ca-app-pub-3940256099942544/1712485313` |

iOS配信時は、App Store審査対応として `Info.plist` に `SKAdNetworkItems` を追加することを推奨(AdMob公式ドキュメント参照)。

## iOSビルド・App Store配信について

このプロジェクトはWindows上で作成しているため、iOSの実機ビルド・コード署名・App Store提出には**別途Mac環境**(実機Mac、またはCodemagic等のクラウドMacビルドサービス)が必要。

Macでの大まかな流れ:

1. このリポジトリをMacに転送し、`flutter pub get`
2. `cd ios && pod install`
3. Xcodeで `ios/Runner.xcworkspace` を開き、Signing & Capabilities でApple DeveloperチームとBundle IDを設定
4. `flutter build ipa` でアーカイブを作成、または Xcode から Product > Archive
5. Transporter または Xcode Organizer から App Store Connect にアップロードし、TestFlight → 審査提出

Codemagicなど クラウドMacビルドサービスを使う場合は、リポジトリをGit管理下に置いてから接続すると自動ビルドできる(現状このディレクトリは未Git管理)。
