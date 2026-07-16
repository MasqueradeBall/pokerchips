-- ポーカーチップアプリ: Supabaseスキーマ(次フェーズでオンライン対戦を実装する際に使用)
--
-- 現在のアプリはこのスキーマを使用していない(ローカルモック版のみ)。
-- Supabaseプロジェクトを作成したら、SQL Editorでこのファイルをそのまま実行することを想定している。
--
-- 認証は Supabase Anonymous Sign-in (auth.signInAnonymously()) を使う前提。
-- 各クライアントのauth.uid()をplayers.user_idに紐づけ、RLSで
-- 「自分のplayer行だけ更新できる」「自分が参加しているroomのデータだけ見える」を保証する。
-- これはあくまで最初のたたき台であり、本番投入前に必ずセキュリティレビューを行うこと。

create extension if not exists "pgcrypto";

create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text unique not null,
  host_player_id uuid,
  pot integer not null default 0,
  highest_bet integer not null default 0,
  current_phase text not null default 'lobby',
  turn_order uuid[] not null default '{}',
  pending_to_act uuid[] not null default '{}',
  last_action jsonb,
  system_message text,
  ad_waiting_player_id uuid,
  ad_waiting_deadline timestamptz,
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
  is_bot boolean not null default false,
  created_at timestamptz not null default now()
);

-- Undo機能(直近1手のみ取り消し)を実現するための行動履歴。
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

-- 自分が参加しているroomだけ参照可能
create policy "rooms_select_member" on rooms for select
  using (
    exists (
      select 1 from players
      where players.room_id = rooms.id
        and players.user_id = auth.uid()
    )
  );

-- ルーム作成は誰でも可能(作成時点ではまだplayer行が無いため)
create policy "rooms_insert_any" on rooms for insert
  with check (true);

create policy "rooms_update_member" on rooms for update
  using (
    exists (
      select 1 from players
      where players.room_id = rooms.id
        and players.user_id = auth.uid()
    )
  );

create policy "players_select_roommate" on players for select
  using (
    exists (
      select 1 from players self
      where self.room_id = players.room_id
        and self.user_id = auth.uid()
    )
  );

create policy "players_insert_self" on players for insert
  with check (user_id = auth.uid());

-- 自分の行、またはホスト(キック/借金付与など)が更新可能。
-- ホスト権限の正確な検証はアプリ側のRPC関数で行うことを推奨。
create policy "players_update_self_or_host" on players for update
  using (
    user_id = auth.uid()
    or exists (
      select 1 from rooms
      where rooms.id = players.room_id
        and rooms.host_player_id = (
          select id from players p2 where p2.room_id = players.room_id and p2.user_id = auth.uid()
        )
    )
  );

create policy "action_logs_select_roommate" on action_logs for select
  using (
    exists (
      select 1 from players
      where players.room_id = action_logs.room_id
        and players.user_id = auth.uid()
    )
  );

create policy "action_logs_insert_roommate" on action_logs for insert
  with check (
    exists (
      select 1 from players
      where players.room_id = action_logs.room_id
        and players.user_id = auth.uid()
    )
  );

-- Realtimeで変更を配信できるようにする
alter publication supabase_realtime add table rooms;
alter publication supabase_realtime add table players;
alter publication supabase_realtime add table action_logs;
