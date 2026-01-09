# JyogiRooms

## はじめに

このアプリケーションを開始するには、`devbox` がインストールされている必要があります。

1. **リポジトリをクローンする:**
   ```bash
   git clone <repository_url>
   cd JyogiRooms
   ```

2. **セットアップスクリップの実行:**
   以下のコマンドを実行すると、依存関係のインストール、データベース（PostgreSQL）の構築、および全ての準備が自動的に行われます。
   ```bash
   devbox run setup
   ```

3. **サーバーの起動:**
   セットアップスクリプトによってサーバーは自動的に起動しますが、次回以降は以下のコマンドを使用してください。
   ```bash
   devbox run dev
   ```

## 開発

- **テストの実行:**
  ```bash
  devbox run test
  ```
- **コードの整形（Lint）:**
  ```bash
  devbox run lint
  ```