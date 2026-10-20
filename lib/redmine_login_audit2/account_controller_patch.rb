# frozen_string_literal: true

module RedmineLoginAudit2
  module AccountControllerPatch
    # Core's password_authentication is left in charge: replacing it skipped two-factor authentication and the
    # active check. Failures are recorded where core reports them instead, which also covers SSO plugins that report
    # through the same methods (redmine_oauth does). Successes are recorded by the hook in hooks.rb.

    # SAMLコールバック用のオーバーライド（redmine_samlプラグイン対応）
    # ロックされたユーザーがSSO経由でログインしようとした場合の失敗を記録
    def login_with_saml_callback
      # redmine_samlがインストールされていない場合はスキップ
      unless RedmineLoginAudit2.saml_plugin_installed?
        return super if defined?(super)
        return render_404
      end

      begin
        auth = request.env['omniauth.auth']
        if auth.present?
          # redmine_samlと同じ方法でユーザーを取得
          user = User.find_or_create_from_omniauth(auth)
          if user.blank?
            # ユーザーが見つからない/作成できない
            LoginAudit.failure(nil, request, { username: auth[:uid] })
          elsif !user.active?
            # ユーザーは存在するがロック/無効化されている
            LoginAudit.failure(user, request, { username: user.login })
          end
        end
      rescue => e
          Rails.logger.error "LoginAudit: Error in SAML callback: #{e.message}"
      end
      # 元のメソッド（redmine_samlのlogin_with_saml_callback）を呼び出す
      super
    end

    # SAML認証失敗時のコールバック
    def login_with_saml_failure
      # redmine_samlがインストールされていない場合はスキップ
      unless RedmineLoginAudit2.saml_plugin_installed?
        return super if defined?(super)
        return render_404
      end

      LoginAudit.failure(nil, request, { username: params[:message] || 'saml_failure' })
      super
    end

    private

    # Wrong login or password, or a user an SSO plugin could not match
    def invalid_credentials
      LoginAudit.failure(nil, request, params)
      super
    end

    # Right credentials, but the account is locked or not activated yet
    def account_locked(user, redirect_path = signin_path)
      LoginAudit.failure(user, request, params) if login_attempt?
      super
    end

    def account_pending(user, redirect_path = signin_path)
      LoginAudit.failure(user, request, params) if login_attempt?
      super
    end

    # Core also reaches account_locked and account_pending from password recovery and from a registration awaiting
    # approval, which are not logins
    def login_attempt?
      %w[lost_password register].exclude?(action_name)
    end
  end
end
