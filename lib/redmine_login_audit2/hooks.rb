# frozen_string_literal: true

module RedmineLoginAudit2
  module Hooks
    # ログイン成功時のフック
    class ControllerAccountSuccessAuthenticationAfterHook < Redmine::Hook::ViewListener
      def controller_account_success_authentication_after(context = {})
        user = context[:user]
        request = context[:request]
        params = context[:params]

        # アクティブユーザーのみ成功を記録
        # ロック/無効化ユーザーは successful_authentication が呼ばれても
        # 実際にはログインできないので、成功として記録しない
        if user&.active?
          LoginAudit.success(user, request, params)
        else
          Rails.logger.info "LoginAudit: Skipping success record for inactive user '#{user&.login}' (status=#{user&.status})"
        end
      end
    end

    # スタイルシート読み込み
    class ViewLayoutsBaseHtmlHeadHook < Redmine::Hook::ViewListener
      def view_layouts_base_html_head(context)
        controller = context[:controller]

        # 管理画面またはLoginAuditコントローラーの場合のみCSSを読み込む
        if controller.is_a?(AdminController) ||
           controller.is_a?(SettingsController) ||
           controller.class.name == 'LoginAuditController'
          stylesheet_link_tag('login_audit', plugin: :redmine_login_audit2)
        end
      end
    end
  end
end
