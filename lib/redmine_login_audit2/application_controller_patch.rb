# frozen_string_literal: true

module RedmineLoginAudit2
  module ApplicationControllerPatch
    def user_setup
      super

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

    def audit_api_enabled?
      settings = Setting.plugin_redmine_login_audit2
      settings.is_a?(Hash) && settings['audit_api'] == '1'
    end
  end
end
