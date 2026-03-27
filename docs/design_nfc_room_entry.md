# NFC入退室管理機能 設計書

## 概要

部室に設置したRaspberry PiにNFCカードリーダーを接続し、学生証などのNFCカードをかざすことで入退室管理を行う。Railsアプリ側にAPIとして全処理を実装し、Raspi側はカード読み取り→API送信のみを担う。

## アーキテクチャ

```
┌─────────────┐     HTTP      ┌──────────────────┐      ┌──────────┐
│  NFC Raspi   │ ──────────→  │   Rails API       │ ───→ │ NeonDB   │
│ (部室設置)    │              │ (ラズパイ常時稼働)  │      │(PostgreSQL)│
└─────────────┘              └──────────────────┘      └──────────┘
                                     │
┌─────────────┐     HTTP             │  Discord通知
│  Webアプリ    │ ←──────────→        ↓
│              │              ┌──────────────────┐
└─────────────┘              │   Discord API     │
                              └──────────────────┘
┌─────────────┐     HTTP      ┌──────────────────┐
│ Discord Bot  │ ──────────→  │   Rails API       │
│              │              │  (同上)            │
└─────────────┘              └──────────────────┘
```

### 方針

- **Rails APIに全ロジックを集約**。NFC Raspiはカード読み取りとAPI呼び出しのみ
- **DBはNeonDB（PostgreSQL）をそのまま使用**。Redis等の追加は不要（入退室は1日数十〜百回程度）
- **サービス層でロジックを共通化**。API同士が呼び合うことはしない
- **Discord通知は既存のDiscordNotifierを拡張**

---

## テーブル設計

### nfc_cards（NFCカード登録）

| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | bigint | PK | |
| user_id | bigint | FK, NOT NULL, UNIQUE | 所有ユーザー（1人1枚） |
| card_uid | string | NOT NULL, UNIQUE | NFCカードのUID |
| student_id | string | | 学籍番号（任意） |
| student_name | string | | 氏名（任意） |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

- **1ユーザー1枚のみ登録可能**（user_idにユニーク制約）
- `student_id`・`student_name`は学生証で登録した場合のみ保存される（学生証以外のNFCカードでも登録可能）

### nfc_registration_requests（NFC登録待ち）

| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | bigint | PK | |
| user_id | bigint | FK, NOT NULL | 登録待ちユーザー |
| card_uid | string | | かざされたカードUID（読み取り後に保存） |
| student_id | string | | 学籍番号（読み取り後に保存） |
| student_name | string | | 氏名（読み取り後に保存） |
| expires_at | datetime | NOT NULL | 有効期限（作成から1分） |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

- **pending状態のレコードは同時に1件のみ**（有効期限内のレコードが存在する場合、新規作成不可）
- 有効期限切れのレコードは自動的に無効となり、定期的に削除される

### room_visits（入退室記録）

| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | bigint | PK | |
| room_id | bigint | FK, NOT NULL | 部室 |
| user_id | bigint | FK, NOT NULL | ユーザー |
| entered_at | datetime | NOT NULL | 入室時刻 |
| exited_at | datetime | | 退室時刻（NULLなら入室中） |
| source | string | NOT NULL, default: "nfc" | 入室元（nfc / web / discord） |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

- `exited_at IS NULL` → 現在入室中のユーザー

### room_sessions（開閉室記録・統計用）

| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | bigint | PK | |
| room_id | bigint | FK, NOT NULL | 部室 |
| opened_by_id | bigint | FK, NOT NULL | 開室したユーザー |
| closed_by_id | bigint | FK | 閉室したユーザー（NULLなら開室中） |
| opened_at | datetime | NOT NULL | 開室時刻 |
| closed_at | datetime | | 閉室時刻（NULLなら開室中） |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

- `closed_at IS NULL` → 現在開室中
- 統計用途：曜日別の開室時間、誰がよく開けているか等を集計可能

### room_status（部室状況スナップショット・参照専用）

| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | bigint | PK | |
| room_id | bigint | FK, NOT NULL, UNIQUE | 部室（1部室1レコード） |
| is_open | boolean | NOT NULL, default: false | 現在開室中か |
| opened_at | datetime | | 開室時刻（is_open=falseの時はNULL） |
| opened_by_id | bigint | FK | 開室したユーザー（is_open=falseの時はNULL） |
| occupant_count | integer | NOT NULL, default: 0 | 現在の在室人数 |
| occupants | jsonb | NOT NULL, default: [] | 在室中ユーザーのスナップショット |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

`occupants` JSONBの形式:
```json
[
  {
    "user_id": 1,
    "display_name": "田中太郎",
    "entered_at": "2026-03-27T10:05:00+09:00"
  }
]
```

**設計方針:**
- **1部室1レコードのみ**。`room_id` にUNIQUE制約
- **読み取り専用の窓口**。状況確認（WebアプリとDiscord Bot）はこのテーブルのみ参照
- `room_visits` / `room_sessions` への記録は行うが、部室状況確認の処理では使わない
- 在室者情報はJSONBで非正規化して保持するため、状況確認時にJOINが不要
- `display_name` はエントリ時点のスナップショット（入退室のたびに更新されるため実用上は常に最新）
- Roomレコード作成時に `after_create` コールバックで対応する `room_status` を自動生成（`is_open: false`, `occupants: []`）

---

## API設計

### 認証

NFC Raspiからのリクエストは既存の`X-Api-Key`ヘッダー認証を使用。

### エンドポイント一覧

#### 入退室

| メソッド | パス | 用途 | クライアント |
|----------|------|------|------------|
| POST | `/api/rooms/:room_id/touch` | NFC自動判定（入室/退室/カード登録） | NFC Raspi |
| POST | `/api/rooms/:room_id/enter` | 入室 | Discord Bot |
| POST | `/api/rooms/:room_id/exit` | 退室 | Webアプリ, Discord Bot |

#### 開閉室

| メソッド | パス | 用途 | 権限 | クライアント |
|----------|------|------|------|------------|
| POST | `/api/rooms/:room_id/open` | 開室 | 鍵持ち/管理者 | Discord Bot |
| POST | `/api/rooms/:room_id/close` | 閉室 | 鍵持ち/管理者 | Webアプリ, Discord Bot |

#### NFC登録

| メソッド | パス | 用途 | クライアント |
|----------|------|------|------------|
| POST | `/api/nfc_registrations` | 登録開始（pending作成） | Webアプリ |
| GET | `/api/nfc_registrations/:id` | 登録状態確認（ポーリング） | Webアプリ |
| PATCH | `/api/nfc_registrations/:id/confirm` | 登録確定 | Webアプリ |
| DELETE | `/api/nfc_registrations/:id` | 登録キャンセル | Webアプリ |

#### 状況確認

| メソッド | パス | 用途 | クライアント |
|----------|------|------|------------|
| GET | `/api/rooms/:room_id/status` | 部室状況（開閉・入室者一覧） | Webアプリ, Discord Bot |

> **参照テーブル:** `room_status` のみ。`room_visits` / `room_sessions` は参照しない。

---

## API詳細

### POST /api/rooms/:room_id/touch

NFC Raspi専用。カードUIDから自動で入室/退室/カード登録を判定。

**リクエスト:**
```json
{
  "card_uid": "ABC123",
  "student_id": "24A001",
  "student_name": "田中太郎"
}
```

**処理フロー:**
```
1. card_uidでnfc_cardsを検索
2. 未登録の場合:
   a. 有効なnfc_registration_requestsがあるか確認
   b. あれば → card_uidを保存（登録フロー）
   c. なければ → 未登録エラー
3. 登録済みの場合:
   a. そのユーザーがroom_idに入室中か確認（exited_at IS NULL）
   b. 入室中 → 退室処理（RoomEntryService.exit）
      → 退室後にその部室の入室者が0人になった場合は閉室処理も実行（RoomStateService.close）
   c. 入室中でない → 入室処理（RoomEntryService.enter）
      → 別の部室に入室中の場合はその部室の退室処理を先に実行
      → 部室が閉まっている場合は開室処理も同時に実行（RoomStateService.open）
```

**レスポンス:**
```json
{
  "action": "enter",
  "user": { "id": 1, "display_name": "田中太郎" },
  "room": { "id": 3, "name": "第3部室" },
  "timestamp": "2026-03-25T15:00:00+09:00"
}
```

### POST /api/rooms/:room_id/enter

明示的な入室処理。**Discord Botからのみ利用可能**（Webアプリからは不可）。

**リクエスト:**
```json
{ "discord_user_id": "123456789" }
```

### POST /api/rooms/:room_id/exit

明示的な退室処理。Webアプリ・Discord Botから利用可能。
Webアプリでは現在入室中の部室からのみ退室可能。

**リクエスト:**
```json
{ "user_id": 1 }
```
または Discord Bot の場合:
```json
{ "discord_user_id": "123456789" }
```

### POST /api/rooms/:room_id/open

開室処理。**Discord Botからのみ利用可能**（Webアプリからは不可）。

**権限:**
- **鍵持ち**: 自身が鍵を持っている部室のみ開室可能
- **管理者**: 全ての部室を開室可能

**リクエスト:**
```json
{ "discord_user_id": "123456789" }
```

**処理:** 開室 + Discord通知

### POST /api/rooms/:room_id/close

閉室処理。Webアプリ・Discord Botから利用可能。

**権限:**
- **鍵持ち**: 自身が鍵を持っている部室のみ閉室可能
- **管理者**: 全ての部室を閉室可能

**処理:**
1. 閉室
2. 入室中の全ユーザーを退室処理
3. Discord通知

---

## NFC登録フロー

```
Webアプリ                      Rails API                    NFC Raspi
    │                              │                           │
    │  POST /api/nfc_registrations │                           │
    │  { user_id: 5 }             │                           │
    │ ──────────────────────────→  │                           │
    │                              │ pending作成               │
    │                              │ (expires_at: 1分後)       │
    │  ← 201 { id: 1 }            │                           │
    │                              │                           │
    │  「カードをかざしてください」    │                           │
    │  画面表示                     │                           │
    │                              │                           │
    │  GET /nfc_registrations/1    │                           │
    │ ──────────────────────────→  │                           │  カードかざす
    │  ← { card_uid: null }        │                           │
    │                              │  POST /rooms/:id/touch    │
    │  GET /nfc_registrations/1    │  { card_uid: "ABC123" }   │
    │ ──────────────────────────→  │ ←─────────────────────────│
    │                              │  未登録 + pending有り      │
    │                              │  → card_uid保存            │
    │  ← { card_uid: "ABC123" }   │                           │
    │                              │                           │
    │  カードUID表示                │                           │
    │  「このカードを登録しますか？」 │                           │
    │                              │                           │
    │  PATCH /nfc_registrations/1/confirm                      │
    │ ──────────────────────────→  │                           │
    │                              │ nfc_cards作成             │
    │                              │ pending削除               │
    │  ← 200 OK                    │                           │
```

### 制約

- pendingレコードは同時に1件のみ存在可能
- 登録開始時に有効なpendingが存在する場合はエラー（「他のユーザーが登録中です」）
- 有効期限は作成から1分
- 期限切れのpendingは次のリクエスト時にクリーンアップ

---

## サービス層

### RoomEntryService

```ruby
class RoomEntryService
  def self.enter(room, user, source: "web")
    # 既に入室中ならエラー
    # room_visitsにレコード作成（記録）
    # room_status.occupantsにユーザーを追加、occupant_countをインクリメント（参照用更新）
    # Discord通知
  end

  def self.exit(room, user)
    # 入室中でなければエラー
    # room_visits.exited_atを現在時刻に更新（記録）
    # room_status.occupantsからユーザーを除去、occupant_countをデクリメント（参照用更新）
    # Discord通知
  end

  def self.toggle(room, user)
    # 入室中ならexit、そうでなければenter
  end
end
```

### RoomStateService

```ruby
class RoomStateService
  def self.open(room, user)
    # 既に開室中ならエラー
    # room_sessionsにレコード作成（opened_by, opened_at）（記録）
    # room_status.is_open=true, opened_at, opened_by_idを更新（参照用更新）
    # Discord通知
  end

  def self.close(room, user)
    # 開室中でなければエラー
    # 入室中の全ユーザーを退室処理（room_visits.exited_at更新）（記録）
    # room_sessionsのclosed_at, closed_by更新（記録）
    # room_status.is_open=false, opened_at/opened_by_id=NULL, occupants=[], occupant_count=0（参照用更新）
    # Discord通知
  end
end
```

※ 権限チェック（鍵持ち/管理者）はAPIコントローラー層（`authorize_key_holder!`）で実施

### room_statusの更新タイミングまとめ

| イベント | 更新内容 |
|---------|---------|
| 開室（open） | `is_open=true`, `opened_at`, `opened_by_id` を設定 |
| 閉室（close） | `is_open=false`, `opened_at/opened_by_id=NULL`, `occupants=[]`, `occupant_count=0` |
| 入室（enter） | `occupants` に `{user_id, display_name, entered_at}` を追加、`occupant_count+1` |
| 退室（exit） | `occupants` から該当ユーザーを除去、`occupant_count-1` |
| 部屋作成（Room.create） | `room_status` レコードを自動生成（is_open: false, occupants: []） |

---

## Discord通知

既存の`DiscordNotifier`に以下の通知タイプを追加:

| タイプ | タイトル | 色 |
|--------|---------|------|
| room_entered | 📱 入室しました | 緑 (0x00cc66) |
| room_exited | 📱 退室しました | オレンジ (0xff9900) |
| room_opened | 🔓 部室が開きました | 青 (0x0099ff) |
| room_closed | 🔒 部室が閉まりました | 赤 (0xff3333) |

---

## Webアプリ画面

### 部室状況ページ（新規）

- 各部室の開閉状態
- 現在入室中のユーザー一覧
- 退室ボタン（自分が入室中の部室のみ表示）
- 閉室ボタン（鍵持ち: 自分の鍵の部室のみ / 管理者: 全部室）
- ※入室・開室はNFCまたはDiscordからのみ行う

### NFC登録ページ（新規）

- 登録開始ボタン
- カード待ち状態の表示（ポーリング）
- 読み取ったカードUIDの確認・確定

### マイページ等への追加

- 登録済みNFCカード一覧
- カード削除機能

---

## Discord Botコマンド

| コマンド | 説明 | 権限 |
|---------|------|------|
| `/open <部室番号>` | 部室を開室 | 鍵持ち/管理者 |
| `/close <部室番号\|all>` | 部室を閉室（`all`で全部室を閉室） | 鍵持ち/管理者（`all`は管理者のみ） |
| `/enter <部室番号>` | 入室登録 | 全ユーザー |
| `/exit <部室番号>` | 退室登録 | 全ユーザー |
| `/status [部室番号\|all]` | 部室状況確認（省略時は全部室） | 全ユーザー |

- `room` パラメータは部室番号を数字で指定（例: `1`, `2`, `3`）
- `/close` と `/status` は `all` を指定すると全部室が対象

---

## 実装順序

### Phase 1: 基盤

1. マイグレーション作成（nfc_cards, nfc_registration_requests, room_visits, roomsカラム追加）
2. モデル作成
3. サービス層実装（RoomEntryService, RoomStateService）

### Phase 2: NFC連携

4. touch API実装
5. NFC登録API実装
6. NFC登録Webページ実装

### Phase 3: Web・通知

7. enter/exit/open/close API実装
8. Discord通知追加
9. 部室状況Webページ実装

### Phase 4: Discord Bot連携

10. Discord Botにコマンド追加（/open, /close, /enter, /exit, /status）
11. 開閉室APIに鍵持ち/管理者の権限チェック追加
12. 既存コマンド（/key, /call）のパラメータを部室番号形式に統一
