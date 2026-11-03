# frozen_string_literal: true

module RedmineLoginAudit2
  # Set on a response whose login failed, naming why. The load balancer counts these per source IP and must strip the
  # header before the response leaves the edge
  FAILED_LOGIN_HEADER = 'X-Login-Failed-Reason'

  class << self
    def setup
      # Load patches
      require File.dirname(__FILE__) + '/redmine_login_audit2/account_controller_patch'
      require File.dirname(__FILE__) + '/redmine_login_audit2/application_controller_patch'
      require File.dirname(__FILE__) + '/redmine_login_audit2/hooks'

      # Apply patches
      unless AccountController.included_modules.include?(RedmineLoginAudit2::AccountControllerPatch)
        AccountController.prepend(RedmineLoginAudit2::AccountControllerPatch)
      end

      unless ApplicationController.included_modules.include?(RedmineLoginAudit2::ApplicationControllerPatch)
        ApplicationController.prepend(RedmineLoginAudit2::ApplicationControllerPatch)
      end

      # Check if redmine_saml plugin is installed
      if saml_plugin_installed?
        Rails.logger.info 'LoginAudit2: redmine_saml plugin detected, SAML callback monitoring enabled'
      else
        Rails.logger.info 'LoginAudit2: redmine_saml plugin not detected, SAML callback monitoring disabled'
      end
    end

    # Redmine applies plugin defaults only while no settings row exists, so an install configured before this
    # setting existed has no value for it: absent means enabled
    def failed_login_header_enabled?
      settings = Setting.plugin_redmine_login_audit2
      !settings.is_a?(Hash) || settings['failed_login_header'].to_s != '0'
    end

    def saml_plugin_installed?
      Redmine::Plugin.installed?(:redmine_saml)
    rescue
      false
    end
  end
end
