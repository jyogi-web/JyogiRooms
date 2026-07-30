# JyogiRooms API リファレンス

## 認証

全エンドポイントにリクエストヘッダーで API キーを付与する。

```
X-Api-Key: <API_ACCESS_TOKEN>
```

---

## 部室

### GET `/api/rooms/:room_id/status` — 部室の状態取得

**パスパラメータ**

| パラメータ | 型 | 説明 |
|---|---|---|
| `room_id` | integer | 部室ID |

**レスポンス例**

```json
{
  "room": { "id": 1, "name": "部室A" },
  "is_open": true,
  "opened_at": "2026-04-10T10:00:00+09:00",
  "opened_by": { "id": 42, "display_name": "田中太郎" },
  "occupants": [
    { "id": 42, "display_name": "田中太郎", "entered_at": "2026-04-10T10:05:00+09:00" }
  ],
  "occupant_count": 1
}
```

**エラー**

| ステータス | 説明 |
|---|---|
| 404 | 部室が見つかりません |

---

### POST `/api/rooms/:room_id/open` — 開室

鍵持ちユーザーまたは管理者のみ実行可能。

**パスパラメータ**

| パラメータ | 型 | 説明 |
|---|---|---|
| `room_id` | integer | 部室ID |

**リクエストボディ**

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| `discord_user_id` | string | `user_id` と択一 | Discord ユーザーID |
| `user_id` | integer | `discord_user_id` と択一 | システムユーザーID |

**レスポンス例**

```json
{
  "action": "open",
  "user": { "id": 42, "display_name": "田中太郎" },
  "room": { "id": 1, "name": "部室A" },
  "timestamp": "2026-04-10T10:00:00+09:00"
}
```

**エラー**

| ステータス | 説明 |
|---|---|
| 403 | 鍵持ちまたは管理者でない |
| 404 | 部室 / ユーザーが見つからない |
| 422 | すでに開室済みなど業務エラー |

---

### POST `/api/rooms/:room_id/close` — 閉室

鍵持ちユーザーまたは管理者のみ実行可能。

**パスパラメータ**

| パラメータ | 型 | 説明 |
|---|---|---|
| `room_id` | integer | 部室ID |

**リクエストボディ**

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| `discord_user_id` | string | `user_id` と択一 | Discord ユーザーID |
| `user_id` | integer | `discord_user_id` と択一 | システムユーザーID |

**レスポンス例**

```json
{
  "action": "close",
  "user": { "id": 42, "display_name": "田中太郎" },
  "room": { "id": 1, "name": "部室A" },
  "timestamp": "2026-04-10T12:00:00+09:00"
}
```

**エラー**

| ステータス | 説明 |
|---|---|
| 403 | 鍵持ちまたは管理者でない |
| 404 | 部室 / ユーザーが見つからない |
| 422 | すでに閉室済みなど業務エラー |

---

### POST `/api/rooms/:room_id/enter` — 入室

**パスパラメータ**

| パラメータ | 型 | 説明 |
|---|---|---|
| `room_id` | integer | 部室ID |

**リクエストボディ**

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| `discord_user_id` | string | `user_id` と択一 | Discord ユーザーID |
| `user_id` | integer | `discord_user_id` と択一 | システムユーザーID |
| `source` | string | 任意 | `nfc` / `web` / `discord`（デフォルト: `discord`） |

**レスポンス例**

```json
{
  "action": "enter",
  "user": { "id": 42, "display_name": "田中太郎" },
  "room": { "id": 1, "name": "部室A" },
  "timestamp": "2026-04-10T10:05:00+09:00"
}
```

**エラー**

| ステータス | 説明 |
|---|---|
| 404 | 部室 / ユーザーが見つからない |
| 422 | 業務エラー（例: すでに入室中） |

---

### POST `/api/rooms/:room_id/exit` — 退室

**パスパラメータ**

| パラメータ | 型 | 説明 |
|---|---|---|
| `room_id` | integer | 部室ID |

**リクエストボディ**

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| `discord_user_id` | string | `user_id` と択一 | Discord ユーザーID |
| `user_id` | integer | `discord_user_id` と択一 | システムユーザーID |

**レスポンス例**

```json
{
  "action": "exit",
  "user": { "id": 42, "display_name": "田中太郎" },
  "room": { "id": 1, "name": "部室A" },
  "timestamp": "2026-04-10T12:30:00+09:00"
}
```

**エラー**

| ステータス | 説明 |
|---|---|
| 404 | 部室 / ユーザーが見つからない |
| 422 | 業務エラー（例: 入室記録がない） |

---

## 鍵

### GET `/api/keys` — 鍵持ちユーザー一覧取得

全部室の鍵とその保持者を返す。

**レスポンス例**

```json
[
  {
    "room_id": 1,
    "room_name": "部室A",
    "room_number": "101",
    "keys": [
      {
        "id": 1,
        "holder": {
          "id": 42,
          "username": "tanaka",
          "display_name": "田中太郎",
          "discord_id": "123456789012345678"
        }
      }
    ]
  }
]
```

---

## 予約

### GET `/api/reservations` — 予約一覧取得

**クエリパラメータ**

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| `start_from` | datetime | 任意 | この日時以降の予約に絞り込む（例: `2026-04-10T00:00:00+09:00`） |
| `end_to` | datetime | 任意 | この日時以前の予約に絞り込む |

**レスポンス例**

```json
[
  {
    "id": 1,
    "start_at": "2026-04-10T13:00:00.000+09:00",
    "end_at": "2026-04-10T15:00:00.000+09:00",
    "purpose": "輪読会",
    "user": {
      "id": 42,
      "username": "tanaka",
      "display_name": "田中太郎",
      "discord_id": "123456789012345678",
      "avatar_url": "https://cdn.discordapp.com/..."
    }
  }
]
```

---

### POST `/api/reservations` — 予約作成

**リクエストボディ**

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| `discord_user_id` | string | `user_id` と択一 | Discord ユーザーID |
| `user_id` | integer | `discord_user_id` と択一 | システムユーザーID |
| `reservation[start_at]` | datetime | 必須 | 予約開始日時 |
| `reservation[end_at]` | datetime | 必須 | 予約終了日時 |
| `reservation[purpose]` | string | 任意 | 利用目的 |

**レスポンス例**

```json
{
  "id": 2,
  "start_at": "2026-04-11T14:00:00.000+09:00",
  "end_at": "2026-04-11T16:00:00.000+09:00",
  "purpose": "もくもく会"
}
```

**エラー**

| ステータス | 説明 |
|---|---|
| 404 | ユーザーが見つからない |
| 422 | バリデーションエラー |

---

### DELETE `/api/reservations/:id` — 予約削除

**パスパラメータ**

| パラメータ | 型 | 説明 |
|---|---|---|
| `id` | integer | 予約ID |

**レスポンス**

成功時: `204 No Content`

**エラー**

| ステータス | 説明 |
|---|---|
| 404 | 予約が見つからない |
| 422 | 削除失敗 |

---

## 統計

### GET `/api/stats/visit_days` — 訪問日数取得

Discord ID を指定してユーザーの訪問日数を取得する。2クエリで完結する軽量エンドポイント。

**クエリパラメータ**

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| `discord_user_id` | string | 必須 | Discord ユーザーID |
| `period` | string | 任意 | 集計期間（デフォルト: `all`） |

**`period` の選択肢**

| 値 | 説明 |
|---|---|
| `today` | 今日 |
| `week` | 今週（月曜始まり） |
| `month` | 今月 |
| `half_year` | 過去6ヶ月 |
| `year` | 過去1年 |
| `all` | 全期間 |

**レスポンス例**

```json
{
  "discord_id": "123456789012345678",
  "period": "month",
  "visit_days": 12
}
```

**エラー**

| ステータス | 説明 |
|---|---|
| 400 | `period` が不正 |
| 404 | ユーザーが見つからない |

---

### GET `/api/stats/me` — ユーザー統計詳細取得

訪問日数・滞在時間・ランキング順位を含む詳細な統計情報を返す。

> **注意:** 複数のDBクエリが発生する重いエンドポイント。単に訪問日数だけが必要な場合は `/api/stats/visit_days` を使うこと。

**クエリパラメータ**

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| `discord_user_id` | string | 必須 | Discord ユーザーID |
| `period` | string | 任意 | 集計期間（デフォルト: `all`、選択肢は `visit_days` と同じ） |

**レスポンス例**

```json
{
  "user": { "id": 42, "display_name": "田中太郎", "discord_id": "123456789012345678" },
  "period": "month",
  "total": { "visit_days": 12, "total_seconds": 144000 },
  "rooms": [
    { "room_id": 1, "room_name": "部室A", "visit_days": 10, "total_seconds": 120000 },
    { "room_id": 2, "room_name": "部室B", "visit_days": 2, "total_seconds": 24000 }
  ],
  "rank": {
    "visit": { "position": 3, "total_users": 50 },
    "duration": { "position": 5, "total_users": 50 },
    "period": "month"
  }
}
```

**エラー**

| ステータス | 説明 |
|---|---|
| 400 | `period` が不正 |
| 404 | ユーザーが見つからない |

---

### GET `/api/stats/ranking` — ランキング取得

**クエリパラメータ**

| パラメータ | 型 | 必須 | 説明 |
|---|---|---|---|
| `type` | string | 任意 | `visits`（訪問日数）/ `duration`（滞在時間）（デフォルト: `visits`） |
| `period` | string | 任意 | 集計期間（デフォルト: `all`、選択肢は `visit_days` と同じ） |
| `room` | string / integer | 任意 | `all` または部室ID（デフォルト: `all`） |

**レスポンス例 (`type=visits`)**

```json
{
  "type": "visits",
  "period": "month",
  "room": "all",
  "ranking": [
    { "rank": 1, "user_id": 42, "display_name": "田中太郎", "discord_id": "123456789012345678", "count": 20 },
    { "rank": 2, "user_id": 7,  "display_name": "鈴木花子",  "discord_id": "987654321098765432", "count": 18 }
  ]
}
```

**レスポンス例 (`type=duration`)**

```json
{
  "type": "duration",
  "period": "all",
  "room": "all",
  "ranking": [
    { "rank": 1, "user_id": 42, "display_name": "田中太郎", "discord_id": "123456789012345678", "total_seconds": 360000 }
  ]
}
```

**エラー**

| ステータス | 説明 |
|---|---|
| 400 | `type` または `period` が不正 |
