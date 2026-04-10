# frozen_string_literal: true

module RedmineLoginAudit2
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

    def saml_plugin_installed?
      Redmine::Plugin.installed?(:redmine_saml)
    rescue
      false
    end
  end
end
