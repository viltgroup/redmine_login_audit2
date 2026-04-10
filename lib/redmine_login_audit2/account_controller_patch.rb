# frozen_string_literal: true

module RedmineLoginAudit2
  module AccountControllerPatch
    # ログイン失敗時のキャプチャ
    # Redmineのpassword_authentication メソッドをオーバーライド
    def password_authentication
      user = User.try_to_login(params[:username], params[:password], false)

      if user.nil?
        # ログイン失敗
        LoginAudit.failure(nil, request, params)
        invalid_credentials
      elsif user.new_record?
        # 自己登録が必要な場合
        onthefly_creation_failed(user, { login: user.login, auth_source_id: user.auth_source_id })
      else
        # ログイン成功（Hooksで記録されるので、ここでは処理しない）
        successful_authentication(user)
      end
    end

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
  end
end
