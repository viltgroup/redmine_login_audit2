# Redmine Login Audit 2

Redmine 6.x 用のログイン監査プラグインです。

[redmine_login_audit](https://github.com/martin-denizet/redmine_login_audit)（Martin Denizet氏作）を Redmine 6.x / Rails 7.2 向けにリファクタリングしました。

## 機能

- **Webログイン記録** - 成功・失敗を記録
- **API認証記録** - REST APIアクセスを記録
- **SSO対応** - SAML経由のロックユーザー失敗ログも記録
- **管理画面** - フィルタリング、ソート、CSVエクスポート
- **ログパージ** - 古いログの一括削除（誤操作防止付き）

## 動作要件

- Redmine 6.0以上
- Ruby 3.2以上
- Rails 7.2

## インストール

### 新規インストール

```bash
cd /path/to/redmine/plugins
git clone https://github.com/seraph3000/redmine_login_audit2.git
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Redmineを再起動してください。

### 旧 redmine_login_audit からの移行

既存データを保持したまま移行できます：

```bash
# 1. 旧プラグイン削除（テーブルは残る）
cd /path/to/redmine
rm -rf plugins/redmine_login_audit

# 2. 新プラグインをインストール
cd plugins
git clone https://github.com/seraph3000/redmine_login_audit2.git

# 3. 状態確認
cd /path/to/redmine
bundle exec rake redmine_login_audit2:check RAILS_ENV=production

# 4. 移行実行
bundle exec rake redmine_login_audit2:migrate_from_v1 RAILS_ENV=production

# 5. Redmine再起動
touch tmp/restart.txt

# 6. (任意) 旧マイグレーションレコード削除
bundle exec rake redmine_login_audit2:cleanup_v1 RAILS_ENV=production
```

### Rakeタスク一覧

| タスク | 説明 |
|--------|------|
| `redmine_login_audit2:check` | 状態確認 |
| `redmine_login_audit2:migrate_from_v1` | 旧プラグインから移行 |
| `redmine_login_audit2:cleanup_v1` | 旧マイグレーションレコード削除 |
| `redmine_login_audit2:stats` | 統計表示 |
| `redmine_login_audit2:purge MONTHS=6` | 古いログ削除 |

## アンインストール

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate NAME=redmine_login_audit2 VERSION=0 RAILS_ENV=production
rm -rf plugins/redmine_login_audit2
```

## 設定

「管理」→「プラグイン」→「Redmine Login Audit 2」→「設定」

| 項目 | 説明 |
|------|------|
| ログ記録設定 | 記録しない / 成功のみ / 失敗のみ / 両方 |
| API監査 | APIアクセスも記録 |
| APIキーをフィルタ | URLのAPIキーを[FILTERED]に置換 |
| 1ページの表示件数 | 管理画面の表示件数 |

## 使い方

「管理」→「ログイン監査」

### フィルター

- ログインID、IPアドレス、成功/失敗、Web/API、日付範囲

### ログ削除

- 指定月数より古いログを削除（最古ログ日付を表示）
- 全削除（チェックボックス確認必須）

## 対応認証方式

| 方式 | 成功 | 失敗 | 備考 |
|------|:----:|:----:|------|
| Redmine標準ログイン | ✓ | ✓ | 組み込み |
| LDAP / Active Directory | ✓ | ✓ | 標準の`try_to_login`経由 |
| REST API | ✓ | ✓ | 組み込み |
| SAML (redmine_saml) | ✓ | ✓ | 組み込み |
| 他のOmniAuth系 | ✓ | — | 失敗は拡張が必要 |

**成功ログ**は Redmine の `controller_account_success_authentication_after` フック経由で全認証方式に対応。

**失敗ログ**は OmniAuth 系プラグインごとにコールバックが異なるため、個別対応が必要。

## 他のOmniAuthプラグインへの拡張

redmine_omniauth_google、redmine_omniauth_azure 等を使っている場合、失敗ログを取得するには `lib/redmine_login_audit2/account_controller_patch.rb` を拡張します。

### 手順1: コールバックメソッド名を確認

| プラグイン | コールバック |
|-----------|-------------|
| redmine_saml | `login_with_saml_callback` |
| redmine_omniauth_google | `oauth_google_callback` |
| redmine_omniauth_github | `oauth_github_callback` |
| redmine_omniauth_azure | `oauth_azure_callback` |
| redmine_openid_connect | `oic_callback` |

### 手順2: オーバーライドを追加

```ruby
def oauth_google_callback
  auth = request.env['omniauth.auth']

  if auth.present?
    user = User.find_or_create_from_omniauth(auth)

    if user.blank?
      LoginAudit.failure(nil, request, { username: auth[:uid] || auth.info&.email })
    elsif !user.active?
      LoginAudit.failure(user, request, { username: user.login })
    end
  end

  super
end
```

### ポイント

1. **必ず `super` を呼ぶ** - 元のプラグインの処理を実行
2. **`user.active?` をチェック** - SSOはロックユーザーも返すことがある
3. **成功は記録しない** - フックが自動で処理

### 動かない場合

1. コールバックメソッド名を確認: `grep -r "def.*callback" plugins/redmine_omniauth_*`
2. `find_or_create_from_omniauth` の有無を確認（プラグインによって異なる）
3. プラグインの読み込み順序を確認（アルファベット順）

## オリジナルからの変更点

### 削除した機能

- メール通知（SSO環境では不要）
- wice_grid依存（標準ページネーションに変更）

### 技術的変更

- `alias_method_chain` → `prepend`
- `before_filter` → `before_action`
- `attr_accessible` → 削除（Strong Parameters）
- `unloadable` → 削除

### 新機能

- SAML/SSO対応（ロックユーザー失敗ログ）
- CSVストリーミングエクスポート（1,000件ずつバッチ処理）
- パージUI改善（最古ログ日付表示、折りたたみ）
- 全削除保護（チェックボックス確認必須）
- HTML5日付入力（カレンダーヘルパー不要）

## ライセンス

MIT License

## クレジット

- オリジナル: Martin Denizet
- リファクタリング: seraph3000