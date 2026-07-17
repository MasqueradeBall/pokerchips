-- ポーカーチップアプリ: Supabaseスキーマ(オンライン対戦用)
--
-- Supabaseプロジェクトを作成したら、SQL Editorでこのファイルをそのまま実行する。
-- 既存環境に対して再実行しても安全なように書いてある(テーブルはIF NOT EXISTS、
-- ポリシー/関数はDROP→CREATE)。
--
-- 認証は Supabase Anonymous Sign-in (auth.signInAnonymously()) を使う前提。
-- ダッシュボードの Authentication > Sign In / Providers で
-- "Allow anonymous sign-ins" を有効にしておくこと(デフォルトは無効)。
--
-- 各クライアントのauth.uid()をplayers.user_idに紐づけ、RLSで
-- 「自分のplayer行だけ更新できる」「自分が参加しているroomのデータだけ見える」を保証する。
--
-- ゲーム進行ロジック(PokerChipEngine)はクライアント側で計算し、その結果をこのDBに
-- 書き込む「クライアント主導」方式。サーバー側で不正なアクションを検証するPostgres
-- 関数は用意していないため、悪意のあるクライアントによる不正な書き込みは
-- 現状のRLSだけでは防げない(友人内でのプレイを想定した簡易実装)。
-- version列は同時書き込みの検知(楽観的ロック)用に用意しているが、
-- 現在のクライアント実装では検証まではしていない(last-write-wins)。

create extension if not exists "pgcrypto";

create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text unique not null,
  host_player_id uuid,
  phase text not null default 'lobby',
  pot integer not null default 0,
  highest_bet integer not null default 0,
  turn_order uuid[] not null default '{}',
  pending_to_act uuid[] not null default '{}',
  last_action jsonb,
  system_message text,
  ad_waiting_player_id uuid,
  ad_waiting_deadline timestamptz,
  -- Undo(直前の1手のみ取り消し)用に、直前アクション前のroom+players全体の
  -- スナップショットを保持する。undo実行時にこれを丸ごと書き戻す。
  previous_snapshot jsonb,
  version integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  name text not null,
  chips integer not null default 10000,
  current_bet integer not null default 0,
  hand_contribution integer not null default 0,
  hearts integer not null default 5,
  is_ad_free boolean not null default false,
  borrow_count integer not null default 0,
  status text not null default 'active',
  is_host boolean not null default false,
  version integer not null default 0,
  created_at timestamptz not null default now()
);

-- 以前の下書き版schema.sql(current_phase列など)を既に実行済みの環境向けの
-- 移行措置。CREATE TABLE IF NOT EXISTSは既存テーブルの列を追加/変更しないため、
-- 古い列名が残っている場合はここでリネーム・追加する。
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'rooms' and column_name = 'current_phase'
  ) and not exists (
    select 1 from information_schema.columns
    where table_name = 'rooms' and column_name = 'phase'
  ) then
    alter table rooms rename column current_phase to phase;
  end if;
end $$;

alter table rooms add column if not exists previous_snapshot jsonb;
alter table rooms add column if not exists version integer not null default 0;
alter table players add column if not exists version integer not null default 0;

-- 監査用の行動履歴(Undoの実現には previous_snapshot を使うため、
-- こちらは「誰が何をしたか」の記録用途のみ)。
create table if not exists action_logs (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  action_type text not null,
  amount integer not null default 0,
  created_at timestamptz not null default now()
);

alter table rooms enable row level security;
alter table players enable row level security;
alter table action_logs enable row level security;

-- 「自分がそのroomのplayerかどうか」を判定するヘルパー関数。
-- SECURITY DEFINERでRLSをバイパスして評価することで、
-- players テーブル自身のRLSポリシーからplayersを参照した際の
-- 無限再帰(infinite recursion detected in policy)を回避する。
create or replace function is_room_member(target_room_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from players
    where players.room_id = target_room_id
      and players.user_id = auth.uid()
  );
$$;

drop policy if exists "rooms_select_member" on rooms;
drop policy if exists "rooms_select_authenticated" on rooms;
drop policy if exists "rooms_insert_any" on rooms;
drop policy if exists "rooms_update_member" on rooms;
drop policy if exists "players_select_roommate" on players;
drop policy if exists "players_insert_self" on players;
drop policy if exists "players_update_self_or_host" on players;
drop policy if exists "players_update_roommate" on players;
drop policy if exists "action_logs_select_roommate" on action_logs;
drop policy if exists "action_logs_insert_roommate" on action_logs;

-- ルームコードでの参加(join)にはコード検索が必要なため、
-- サインイン済み(匿名可)であればroomsは閲覧可能にする。
-- コードは友人内共有前提の簡易セキュリティであり、厳密なメンバー制限ではない。
create policy "rooms_select_authenticated" on rooms for select
  using (auth.uid() is not null);

-- ルーム作成は誰でも可能(作成時点ではまだplayer行が無いため)
create policy "rooms_insert_any" on rooms for insert
  with check (true);

create policy "rooms_update_member" on rooms for update
  using (is_room_member(rooms.id));

create policy "players_select_roommate" on players for select
  using (is_room_member(players.room_id));

create policy "players_insert_self" on players for insert
  with check (user_id = auth.uid());

-- クライアント主導方式(PokerChipEngineの計算結果をそのまま書き込む)のため、
-- 「フォールドで他プレイヤーが勝つ」「ストリート進行で全員のcurrent_betがリセットされる」
-- 等、自分以外の行も書き込む場面がある。そのため同じルームのメンバーであれば
-- 誰でも(host以外も)room内の他プレイヤー行を更新できるようにしている。
create policy "players_update_roommate" on players for update
  using (is_room_member(players.room_id));

create policy "action_logs_select_roommate" on action_logs for select
  using (is_room_member(action_logs.room_id));

create policy "action_logs_insert_roommate" on action_logs for insert
  with check (is_room_member(action_logs.room_id));

-- Realtimeで変更を配信できるようにする(既に追加済みならエラーになるため例外を握りつぶす)
do $$
begin
  alter publication supabase_realtime add table rooms;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table players;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table action_logs;
exception when duplicate_object then null;
end $$;
