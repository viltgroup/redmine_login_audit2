# frozen_string_literal: true

module RedmineLoginAudit2
  module ApplicationControllerPatch
    def user_setup
      super

      flag_api_auth_failure

      # API リクエストの場合のみ処理
      return unless api_request?
      return unless audit_api_enabled?

      user = User.current

      if Setting.rest_api_enabled? && accept_api_auth?
        if user&.active? && !user.must_change_password?
          # API認証成功
          LoginAudit.success(user, request, params)
        else
          # API認証失敗（無効なキー、無効なユーザーなど）
          LoginAudit.failure(nil, request, params)
        end
      end
    end

    private

    # The value is a reason, never a count: a successful login sends no header at all
    def flag_login_failure(reason)
      return unless RedmineLoginAudit2.failed_login_header_enabled?

      response.set_header(RedmineLoginAudit2::FAILED_LOGIN_HEADER, reason)
    end

    # Independent of the audit settings. Core tries API credentials on any action that accepts API auth, not only on
    # .json/.xml requests, and every API path it takes yields an active user or none
    def flag_api_auth_failure
      return unless Setting.rest_api_enabled? && accept_api_auth?
      return if User.current.logged?

      reason = api_auth_failure_reason
      flag_login_failure(reason) if reason
    end

    # Follows the order of core's find_current_user. A Basic request that core has already answered itself (2FA active,
    # password change required) had the right password, so it is not flagged
    def api_auth_failure_reason
      if api_key_from_request
        'api_key'
      elsif Doorkeeper::OAuth::Token.from_request(request, *Doorkeeper.config.access_token_methods)
        'token'
      elsif /\ABasic /i.match?(request.authorization.to_s) && !performed?
        'credentials'
      end
    end

    def audit_api_enabled?
      settings = Setting.plugin_redmine_login_audit2
      settings.is_a?(Hash) && settings['audit_api'] == '1'
    end
  end
end
