# Poker Chips (ポーカーチップアプリ)

物理トランプ + アプリでチップ計算とハンド進行を管理するポーカー補助アプリ。
設計書: `pokerchips_design.html`

## 現在の状態: Supabaseによるオンライン対戦(実装済み)

Supabase(Postgres + Realtime)に接続し、複数デバイスでのオンライン対戦ができる。以下を実装済み:

- ルーム作成(ルームID自動発行)/ ルームIDで参加、あいことば入力
- 参加者が揃うまで待機するロビー画面 → ホストがゲーム開始
- Fold / Check / Call / Raise(スライダー+プリセット) / All-in
- ラウンド進行(全員のベットが揃うと自動でストリート進行、システムメッセージ表示)
- オールイン全画面エフェクト
- Undo(直前の1手のみ、host画面で最新アクションのプレイヤーバッジに×ボタン表示)
- ホストによるキック(長押し)+ デッドマネー(賭けていたチップはポットに残る)
- ハート(最大5、1ハンドごとに1減少、あいことばで減少しないフラグ)
- ハートが0になったプレイヤーの動画リワード広告視聴(Googleテスト広告ID)+ 他プレイヤーのロック表示 + 30秒タイムアウト強制キック
- ハンド間待機中のみ可能な+10,000借入、純資産(資産 = 手持ちチップ+今ハンドの賭け金合計−借金額)は常に「参加人数×10,000」を維持
- ショーダウンでの勝者選択(ホストのみ)とポット分配

1台のデバイスでホスト+Bot(簡易AI)と対戦するオフラインデモ実装(`lib/data/local/local_room_repository.dart`)もコードとして残っているが、現在Home画面からは使用していない(`lib/providers/repository_providers.dart` で `SupabaseRoomRepository` に固定している。ローカル版に戻したい場合はここを差し替えるだけで良い)。

## 動かし方

```bash
flutter pub get
flutter test          # ポーカーロジックのユニットテスト
flutter emulators --launch Pixel_9
flutter run           # Androidエミュレータ/実機で起動
```

`google_mobile_ads` は Android / iOS のみ対応のため、Windows desktop では実行できません。

### Web版 / GitHub Pages

```bash
flutter run -d chrome   # ブラウザで起動
flutter build web --release --base-href /pokerchips/
```

- Web ビルドでは `lib/data/ads/ad_service.dart` の条件付きexportにより、広告SDKを使わない `ad_service_web.dart` が使われる。Web では広告を表示せず、動画リワード広告の視聴は常に完了扱い(ハート回復)になる。
- `main` への push で `.github/workflows/deploy-web.yml` が Web 版をビルドし、GitHub Pages(`https://<owner>.github.io/pokerchips/`)へデプロイする。
- 初回のみ、リポジトリの **Settings > Pages > Build and deployment > Source** を **GitHub Actions** に設定しておくこと。

### Supabase側の前提設定

1. `supabase/schema.sql` をSQL Editorで実行済みであること(rooms/players/action_logsテーブル、RLSポリシー、Realtime配信設定)
2. ダッシュボードの **Authentication > Sign In / Providers** で **Allow anonymous sign-ins** を有効にしておくこと(デフォルト無効。これがオフだと起動時の匿名サインインが失敗する)
3. 接続情報は `lib/core/supabase_config.dart` にURL/anon keyを直書きしている(anon keyはRLSで保護される公開キーであり秘密鍵ではないため、リポジトリに含めて問題ない)

## アーキテクチャ

- `lib/models`, `lib/domain/poker_chip_engine.dart` — 純粋なゲームロジック(ベット計算・フェーズ進行・Undo・キック・借金・ハートなど)。`GameState`を受け取り新しい`GameState`を返す副作用のない関数群で、`test/poker_chip_engine_test.dart`でユニットテスト済み。
- `lib/data/room_repository.dart` — バックエンドの抽象interface。
  - `lib/data/supabase/supabase_room_repository.dart` — 本番のオンライン対戦実装。
  - `lib/data/local/local_room_repository.dart` — Bot対戦のオフラインデモ実装(現在未使用)。
- `lib/data/supabase/model_mapping.dart` — ドメインモデル ⇔ Supabaseの行(Map)の相互変換。
- `lib/providers` — Riverpodのprovider/controller。
- `lib/screens` — Home / Play(ロビー含む) / Waiting(ハンド間待機)画面。

### Supabase連携の設計(クライアント主導方式)

サーバー側でアクションを検証するPostgres関数は用意していない。**アクションを行ったクライアントが `PokerChipEngine` でローカルに次の状態を計算し、その結果を rooms/players テーブルにそのまま書き込む**「クライアント主導」方式。他クライアントはRealtime(`*.stream()`)で変更を受け取って画面を更新する。友人内でのプレイを想定した簡易実装であり、悪意のあるクライアントによる不正な書き込みは防げない。

Undo(直前の1手のみ取り消し)は、アクション前の room+players 全体のスナップショットを `rooms.previous_snapshot` (jsonb) に保存しておき、undo実行時にそれを丸ごと書き戻す方式で実現している。

`version` 列(rooms/players両方)は将来の楽観的ロック(同時書き込み検知)用に用意しているが、現在のクライアント実装では検証まではしていない(last-write-wins)。

## 既知の簡略化・制限

- Undoはベットアクション(fold/check/call/raise/allIn)のみが対象。キック・借金・あいことば・広告視聴・ハンド開始・ポット分配は取り消せない(仕様上そうあるべきという判断)。
- 勝者判定(ショーダウン)は物理カードで行われるため、アプリ側では**ホストが勝者を手動選択**する画面を追加している(設計書に明記はないが、チップ分配に必須のため)。
- サイドポット(複数プレイヤーが異なる額でオールインした場合の分割)は未対応。ポットは単一。
- サーバー側でのアクション検証(本人の手番か、不正な金額でないか等)は行っていない。RLSは「同じルームのメンバーかどうか」までしかチェックしない。
- 同時書き込みの競合解決(楽観的ロック)は未実装。ほぼ同時に複数人が操作した場合、後勝ち(last-write-wins)になる。
- ホスト切断時の権限移譲は行わない(設計書通り、復帰まで待機)。

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

1. このリポジトリをMacに転送(または`git clone`)し、`flutter pub get`
2. `cd ios && pod install`
3. Xcodeで `ios/Runner.xcworkspace` を開き、Signing & Capabilities でApple DeveloperチームとBundle IDを設定
4. `flutter build ipa` でアーカイブを作成、または Xcode から Product > Archive
5. Transporter または Xcode Organizer から App Store Connect にアップロードし、TestFlight → 審査提出
