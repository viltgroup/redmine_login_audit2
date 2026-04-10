# frozen_string_literal: true

# Redmine Login Audit 2
#
<<<<<<< HEAD
# Copyright (c) 2015-2018 Martin Denizet
# Copyright (c) 2026 seraph3000
#
# Released under the MIT License.
# See LICENSE file for details.
#
=======
# Copyright (C) 2026 seraph3000
# Based on redmine_login_audit by Martin Denizet
>>>>>>> 52e59ee (v1.0.2: Redmine 7.0 support; migrate filters to core Query API)
# Original: https://github.com/martin-denizet/redmine_login_audit
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2.

require File.dirname(__FILE__) + '/lib/redmine_login_audit2'

Redmine::Plugin.register :redmine_login_audit2 do
  name 'Redmine Login Audit 2'
  author 'seraph3000 (Original: Martin Denizet)'
  description 'Audit login attempts and API access in Redmine'
  version '1.0.2'
  url 'https://github.com/seraph3000/redmine_login_audit2'
  author_url 'https://github.com/seraph3000'

  requires_redmine version_or_higher: '6.0.0'

  settings default: {
    'log_setting' => LoginAudit::LoggingSetting::BOTH,
    'audit_api' => '1',
    'audit_api_filter_out_keys' => '1',
    'audit_rows_per_page' => '25'
  }, partial: 'settings/login_audit_settings'

  menu :admin_menu,
      :login_audit,
      { controller: 'login_audit', action: 'index' },
      caption: :label_login_audit,
      icon: 'stats',
      html: { class: 'icon' },
      if: proc { User.current.admin? }
end

Rails.application.config.after_initialize do
  RedmineLoginAudit2.setup
end

