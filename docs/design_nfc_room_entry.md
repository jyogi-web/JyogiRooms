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
| user_id | bigint | FK, NOT NULL | 所有ユーザー |
| card_uid | string | NOT NULL, UNIQUE | 学生証のNFC UID |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

### nfc_registration_requests（NFC登録待ち）

| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | bigint | PK | |
| user_id | bigint | FK, NOT NULL | 登録待ちユーザー |
| card_uid | string | | かざされたカードUID（読み取り後に保存） |
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

---

## API設計

### 認証

NFC Raspiからのリクエストは既存の`X-Api-Key`ヘッダー認証を使用。

### エンドポイント一覧

#### 入退室

| メソッド | パス | 用途 | クライアント |
|----------|------|------|------------|
| POST | `/api/rooms/:room_id/touch` | NFC自動判定（入室/退室/カード登録） | NFC Raspi |
| POST | `/api/rooms/:room_id/enter` | 入室 | Webアプリ, Discord Bot |
| POST | `/api/rooms/:room_id/exit` | 退室 | Webアプリ, Discord Bot |

#### 開閉室

| メソッド | パス | 用途 | クライアント |
|----------|------|------|------------|
| POST | `/api/rooms/:room_id/open` | 開室 | Discord Bot, Webアプリ |
| POST | `/api/rooms/:room_id/close` | 閉室 | Discord Bot, Webアプリ |

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

---

## API詳細

### POST /api/rooms/:room_id/touch

NFC Raspi専用。カードUIDから自動で入室/退室/カード登録を判定。

**リクエスト:**
```json
{ "card_uid": "ABC123" }
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

明示的な入室処理。

**リクエスト:**
```json
{ "user_id": 1 }
```
または Discord Bot の場合:
```json
{ "discord_user_id": "123456789" }
```

### POST /api/rooms/:room_id/exit

明示的な退室処理。リクエスト形式は`enter`と同じ。

### POST /api/rooms/:room_id/open

開室処理。鍵持ちのみ実行可能。

**リクエスト:**
```json
{ "user_id": 1 }
```

**処理:** `rooms.is_open`を`true`に更新 + Discord通知

### POST /api/rooms/:room_id/close

閉室処理。鍵持ちまたは管理者のみ実行可能。

**処理:**
1. `rooms.is_open`を`false`に更新
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
    # room_visitsにレコード作成
    # Discord通知
  end

  def self.exit(room, user)
    # 入室中でなければエラー
    # exited_atを現在時刻に更新
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
    # 鍵持ちか確認
    # is_open = true, opened_by = user
    # Discord通知
  end

  def self.close(room, user)
    # is_open = false
    # 入室中の全ユーザーを退室処理
    # Discord通知
  end
end
```

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
- 入室/退室ボタン（ログインユーザー用）

### NFC登録ページ（新規）

- 登録開始ボタン
- カード待ち状態の表示（ポーリング）
- 読み取ったカードUIDの確認・確定

### マイページ等への追加

- 登録済みNFCカード一覧
- カード削除機能

---

## Discord Botコマンド（将来）

| コマンド | 説明 |
|---------|------|
| `/open <部室ID>` | 部室を開室（鍵持ち限定） |
| `/close <部室ID\|all>` | 部室を閉室（`all`で全部室を閉室） |
| `/enter <部室ID>` | 入室登録 |
| `/exit` | 退室登録（現在入室中の部室から退室） |
| `/status [部室ID]` | 部室状況確認（部室省略時は全部室の状況を表示） |

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

10. Discord Botにコマンド追加（/open, /enter, /exit, /status）
