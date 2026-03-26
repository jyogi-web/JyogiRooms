# NFC Raspberry Pi 実装ガイド

Raspi側の役割は **NFCカードのUIDを読み取り、Rails APIにPOSTする** だけです。
入退室の判定・開閉室の制御・カード登録などのロジックは全てサーバー側で処理されます。

---

## 呼び出すAPI

### `POST /api/rooms/:room_id/touch`

| 項目 | 値 |
|------|------|
| メソッド | POST |
| URL | `https://<アプリのドメイン>/api/rooms/:room_id/touch` |
| 認証 | `X-Api-Key` ヘッダー |
| Content-Type | `application/json` |

`:room_id` は設置先の部室IDに置き換えてください（固定値）。

### リクエスト

**学生証以外のNFCカードの場合:**
```json
{
  "card_uid": "04A1B2C3D4E5F6"
}
```

**学生証の場合:**
```json
{
  "card_uid": "04A1B2C3D4E5F6",
  "student_id": "24A001",
  "student_name": "田中太郎"
}
```

| パラメータ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| `card_uid` | string | 必須 | NFCカードのUID（16進数文字列） |
| `student_id` | string | 任意 | 学籍番号（学生証から読み取った場合） |
| `student_name` | string | 任意 | 氏名（学生証から読み取った場合） |

### レスポンス

**成功時（200 OK）:**

```json
{
  "action": "enter",
  "user": { "id": 1, "display_name": "田中太郎" },
  "room": { "id": 3, "name": "第3部室" },
  "timestamp": "2026-03-25T15:00:00+09:00"
}
```

`action` の値:
| action | 意味 |
|--------|------|
| `enter` | 入室した |
| `exit` | 退室した |
| `registration` | カード登録された（Webアプリから登録待ち中だった） |

**エラー時（422 Unprocessable Entity）:**

```json
{
  "error": "未登録のカードです"
}
```

主なエラーメッセージ:
- `未登録のカードです` — カードが未登録で、かつ登録待ちリクエストもない
- `既にこの部室に入室中です` — 通常発生しない（トグルで処理するため）

---

## 環境変数

Raspi側で必要な設定値:

| 変数名 | 説明 | 例 |
|--------|------|------|
| `API_URL` | touch APIのURL | `https://example.com/api/rooms/3/touch` |
| `API_KEY` | APIアクセストークン（サーバーの `API_ACCESS_TOKEN` と同じ値） | `your-secret-key` |

---

## Python実装例（nfcpy）

```python
import nfc
import requests
import os
import time

API_URL = os.environ["API_URL"]
API_KEY = os.environ["API_KEY"]

HEADERS = {
    "Content-Type": "application/json",
    "X-Api-Key": API_KEY,
}

def read_student_data(tag):
    """学生証からデータを読み取る（学生証でない場合はNone）"""
    # TODO: 学生証のデータ構造に合わせて実装
    # 例: NDEF読み取り、特定ブロック読み取りなど
    return None

def on_card_touch(tag):
    card_uid = tag.identifier.hex().upper()
    print(f"カード検出: {card_uid}")

    payload = {"card_uid": card_uid}

    # 学生証データが読み取れたら追加（任意）
    student_data = read_student_data(tag)
    if student_data:
        payload["student_id"] = student_data.get("student_id")
        payload["student_name"] = student_data.get("student_name")

    try:
        response = requests.post(
            API_URL,
            json=payload,
            headers=HEADERS,
            timeout=10,
        )
        data = response.json()

        if response.ok:
            action = data["action"]
            user = data["user"]["display_name"]
            print(f"{action}: {user}")
        else:
            print(f"エラー: {data.get('error', '不明なエラー')}")
    except requests.RequestException as e:
        print(f"通信エラー: {e}")

    # Trueを返すとカードが離れるまで次の読み取りをしない（連続読み取り防止）
    return True

def main():
    with nfc.ContactlessFrontend("usb") as clf:
        print("NFCリーダー起動。カードをかざしてください...")
        while True:
            clf.connect(rdwr={"on-connect": on_card_touch})
            time.sleep(0.5)

if __name__ == "__main__":
    main()
```

---

## 注意事項

- **Raspi側にロジックは不要**です。カードUIDをPOSTするだけでサーバーが入室/退室/登録を自動判定します。
- **連続読み取りの防止**を必ず実装してください。同じカードが短時間に何度も送信されると入室→退室が繰り返されます。
- **通信エラー時はリトライせず無視**してOKです。次にカードをかざせば再送信されます。
- `card_uid` の形式（大文字/小文字、区切り文字の有無）はサーバー側と統一してください。上記の例では大文字16進数（`04A1B2C3D4E5F6`）を使用しています。
