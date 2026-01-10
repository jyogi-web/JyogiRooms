require "test_helper"

class AccessTokenTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @active_token = access_tokens(:active)
    @expired_token = access_tokens(:expired)
    @revoked_token = access_tokens(:revoked)
  end

  # ============================================================================
  # バリデーションのテスト
  # ============================================================================
  # AccessTokenモデルのバリデーションルールが正しく機能することを確認
  # これらのテストにより、データの整合性が保証される

  # tokenカラムが必須であることをテスト
  # 目的: トークン値なしでAccessTokenを作成できないことを保証
  # 重要性: トークンは認証の核心であり、空のトークンは無意味
  test "should require token" do
    token = AccessToken.new(user: @user, expires_at: 1.day.from_now)
    assert_not token.valid?
    assert_includes token.errors[:token], "can't be blank"
  end

  # tokenカラムが一意であることをテスト
  # 目的: 同じトークン値を持つAccessTokenが複数存在しないことを保証
  # 重要性: トークンの衝突は重大なセキュリティ問題を引き起こす
  #         同じトークンで複数のユーザーが認証できてしまう
  test "should require unique token" do
    token = AccessToken.new(
      user: @user,
      token: @active_token.token,
      expires_at: 1.day.from_now
    )
    assert_not token.valid?
    assert_includes token.errors[:token], "has already been taken"
  end

  # expires_atカラムが必須であることをテスト
  # 目的: 有効期限なしでAccessTokenを作成できないことを保証
  # 重要性: 有効期限のないトークンは永久に有効となり、セキュリティリスクとなる
  test "should require expires_at" do
    token = AccessToken.new(user: @user, token: "unique_token")
    assert_not token.valid?
    assert_includes token.errors[:expires_at], "can't be blank"
  end

  # ============================================================================
  # インスタンスメソッドのテスト: active?
  # ============================================================================
  # active?メソッドはトークンが使用可能かどうかを判定する重要なメソッド
  # 認証処理の中核で使用されるため、正確な動作が必須

  # アクティブなトークン（未失効かつ未期限切れ）がtrueを返すことをテスト
  # 目的: 正常なトークンが正しく認識されることを保証
  # 条件: revoked=false かつ expires_at > Time.current
  test "active? should return true for non-revoked and non-expired token" do
    assert @active_token.active?
  end

  # 期限切れトークンがfalseを返すことをテスト
  # 目的: 期限切れトークンで認証できないことを保証
  # 条件: expires_at <= Time.current
  # 重要性: 期限切れトークンを拒否しないと、古いトークンが永久に使える
  test "active? should return false for expired token" do
    assert_not @expired_token.active?
  end

  # 失効済みトークンがfalseを返すことをテスト
  # 目的: 手動で失効させたトークンで認証できないことを保証
  # 条件: revoked=true
  # 重要性: ログアウトやセキュリティ侵害時にトークンを無効化できる
  test "active? should return false for revoked token" do
    assert_not @revoked_token.active?
  end

  # ============================================================================
  # インスタンスメソッドのテスト: expired?
  # ============================================================================
  # expired?メソッドはトークンの有効期限切れを判定
  # タイムベースの認証制御に使用される

  # 有効期限前のトークンがfalseを返すことをテスト
  # 目的: まだ有効なトークンが期限切れと誤判定されないことを保証
  # 条件: expires_at > Time.current
  test "expired? should return false for future expiration" do
    assert_not @active_token.expired?
  end

  # 有効期限後のトークンがtrueを返すことをテスト
  # 目的: 期限切れトークンが正しく判定されることを保証
  # 条件: expires_at <= Time.current
  # 重要性: 時間による自動的なアクセス制御を実現
  test "expired? should return true for past expiration" do
    assert @expired_token.expired?
  end

  # ============================================================================
  # インスタンスメソッドのテスト: revoked?
  # ============================================================================
  # revoked?メソッドはトークンが手動で失効されているかを判定
  # ログアウト処理やセキュリティ対応で使用される

  # 未失効トークンがfalseを返すことをテスト
  # 目的: 通常のトークンが失効済みと誤判定されないことを保証
  # 条件: revoked=false
  test "revoked? should return false for non-revoked token" do
    assert_not @active_token.revoked?
  end

  # 失効済みトークンがtrueを返すことをテスト
  # 目的: revoke!で失効させたトークンが正しく判定されることを保証
  # 条件: revoked=true
  test "revoked? should return true for revoked token" do
    assert @revoked_token.revoked?
  end

  # ============================================================================
  # インスタンスメソッドのテスト: revoke!
  # ============================================================================
  # revoke!メソッドはトークンを手動で失効させる
  # ログアウト、セキュリティ侵害対応、強制ログアウトで使用

  # revoke!がrevokedフラグをtrueに設定することをテスト
  # 目的: メソッド呼び出しでインスタンス変数が正しく更新されることを保証
  test "revoke! should mark token as revoked" do
    assert_not @active_token.revoked?
    @active_token.revoke!
    assert @active_token.revoked?
  end

  # revoke!がデータベースを更新することをテスト
  # 目的: 変更が永続化され、リロード後も失効状態が維持されることを保証
  # 重要性: メモリ上だけでなくDBに保存されないと、再起動後に失効が失われる
  test "revoke! should update the database" do
    @active_token.revoke!
    @active_token.reload
    assert @active_token.revoked?
  end

  # revoke!がactive?メソッドの戻り値に影響することをテスト
  # 目的: トークン失効が認証ロジック全体に正しく反映されることを保証
  # 重要性: revoke!を呼んでもactive?がtrueを返すと、失効の意味がない
  test "revoke! should make active? return false" do
    assert @active_token.active?
    @active_token.revoke!
    assert_not @active_token.active?
  end

  # ============================================================================
  # クラスメソッドのテスト: create_for_user
  # ============================================================================
  # create_for_userはjyogi-authから取得したトークンをDBに保存する
  # 新規ログイン、トークンリフレッシュ時に使用される重要なメソッド

  # create_for_userが有効なトークンを作成することをテスト
  # 目的: 必要な全ての属性が正しく設定されることを保証
  # 検証項目: DB保存、ユーザー関連付け、トークン値、初期状態(未失効)
  test "create_for_user should create a valid token" do
    token_value = "test_token_value_#{SecureRandom.hex(8)}"
    token = AccessToken.create_for_user(user: @user, token_value: token_value)

    assert token.persisted?
    assert_equal @user.id, token.user_id
    assert_equal token_value, token.token
    assert_not token.revoked?
  end

  # create_for_userが一意なトークンを生成することをテスト
  # 目的: 複数回呼び出しても異なるトークンが作成されることを保証
  # 重要性: トークン衝突の防止（ただしtoken_valueは外部から渡される）
  test "create_for_user should create unique token" do
    token1 = AccessToken.create_for_user(
      user: @user,
      token_value: "unique_token_1_#{SecureRandom.hex(8)}"
    )
    token2 = AccessToken.create_for_user(
      user: @user,
      token_value: "unique_token_2_#{SecureRandom.hex(8)}"
    )

    assert_not_equal token1.token, token2.token
  end

  # create_for_userがデフォルトで24時間の有効期限を設定することをテスト
  # 目的: expires_inパラメータを省略した場合の動作を保証
  # 重要性: 標準的なセッション時間の設定
  # 誤差許容: 処理時間を考慮して±2秒の誤差を許容
  test "create_for_user should set default expiration to 24 hours" do
    token_value = "test_token_#{SecureRandom.hex(8)}"
    token = AccessToken.create_for_user(user: @user, token_value: token_value)

    expected_expiration = Time.current + 24.hours
    assert_in_delta expected_expiration.to_i, token.expires_at.to_i, 2
  end

  # create_for_userがカスタム有効期限を受け付けることをテスト
  # 目的: 用途に応じた柔軟な有効期限設定が可能なことを保証
  # 使用例: 長期ログイン、一時トークン、管理者セッションなど
  test "create_for_user should allow custom expiration" do
    token_value = "test_token_#{SecureRandom.hex(8)}"
    custom_expires_in = 48.hours
    token = AccessToken.create_for_user(
      user: @user,
      token_value: token_value,
      expires_in: custom_expires_in
    )

    expected_expiration = Time.current + custom_expires_in
    assert_in_delta expected_expiration.to_i, token.expires_at.to_i, 2
  end

  # ============================================================================
  # スコープのテスト: .active, .expired, .revoked
  # ============================================================================
  # これらのスコープは管理画面、統計、バッチ処理で使用される
  # 正確なフィルタリングが必須

  # .activeスコープが使用可能なトークンのみを返すことをテスト
  # 目的: 認証に使えるトークンだけを取得できることを保証
  # 条件: revoked=false かつ expires_at > Time.current
  # 使用例: アクティブセッション一覧、同時ログイン数の制限
  test ".active should return only non-revoked and non-expired tokens" do
    active_tokens = AccessToken.active
    assert_includes active_tokens, @active_token
    assert_not_includes active_tokens, @expired_token
    assert_not_includes active_tokens, @revoked_token
  end

  # .expiredスコープが期限切れトークンのみを返すことをテスト
  # 目的: 期限切れトークンだけを取得できることを保証
  # 条件: expires_at <= Time.current（失効状態は問わない）
  # 使用例: cleanup_expiredメソッド、統計レポート
  test ".expired should return only expired tokens" do
    expired_tokens = AccessToken.expired
    assert_includes expired_tokens, @expired_token
    assert_not_includes expired_tokens, @active_token
  end

  # .revokedスコープが失効済みトークンのみを返すことをテスト
  # 目的: 手動で失効させたトークンだけを取得できることを保証
  # 条件: revoked=true（有効期限は問わない）
  # 使用例: セキュリティ監査、強制ログアウト履歴
  test ".revoked should return only revoked tokens" do
    revoked_tokens = AccessToken.revoked
    assert_includes revoked_tokens, @revoked_token
    assert_not_includes revoked_tokens, @active_token
  end

  # ============================================================================
  # クラスメソッドのテスト: cleanup_expired
  # ============================================================================
  # cleanup_expiredは期限切れトークンをDBから削除する
  # 定期実行バッチジョブで使用され、DBの肥大化を防ぐ

  # cleanup_expiredが期限切れトークンのみを削除することをテスト
  # 目的: 意図したレコードだけが削除されることを保証
  # 重要性: 誤ってアクティブなトークンを削除すると全ユーザーがログアウトされる
  test "cleanup_expired should remove only expired tokens" do
    initial_count = AccessToken.count
    expired_count = AccessToken.expired.count

    AccessToken.cleanup_expired

    assert_equal initial_count - expired_count, AccessToken.count
    assert_equal 0, AccessToken.expired.count
  end

  # cleanup_expiredがアクティブなトークンを削除しないことをテスト
  # 目的: 有効なセッションが維持されることを保証
  # 重要性: これが失敗すると、クリーンアップで全員がログアウトされる
  test "cleanup_expired should not remove active tokens" do
    AccessToken.cleanup_expired
    assert AccessToken.exists?(@active_token.id)
  end

  # cleanup_expiredが失効済みだが期限切れでないトークンを削除しないことをテスト
  # 目的: cleanup_expiredは時間ベースのみで削除し、失効フラグは考慮しないことを保証
  # 理由: 失効済みトークンは監査ログとして残す可能性がある
  test "cleanup_expired should not remove revoked tokens that are not expired" do
    AccessToken.cleanup_expired
    assert AccessToken.exists?(@revoked_token.id)
  end

  # cleanup_expiredが期限切れかつ失効済みトークンを削除することをテスト
  # 目的: 期限切れであれば失効状態に関わらず削除されることを保証
  # 重要性: 両方の条件を満たすトークンも正しく処理される
  test "cleanup_expired should remove expired tokens even if revoked" do
    expired_and_revoked = access_tokens(:expired_and_revoked)
    AccessToken.cleanup_expired
    assert_not AccessToken.exists?(expired_and_revoked.id)
  end
end
