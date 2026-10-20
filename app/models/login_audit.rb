# frozen_string_literal: true

class LoginAudit < ActiveRecord::Base
  belongs_to :user, optional: true

  # before_validation, not before_create: validations run first, so a URL longer than 255 characters (every OAuth
  # callback) was rejected before it could be truncated, and the login went unrecorded
  before_validation :filter_out_api_key
  before_validation :filter_out_oauth_params
  before_validation :truncate_url
  before_validation :truncate_referer

  validates :ip_address, presence: true
  validates :login, length: { maximum: 255 }, allow_blank: true
  validates :url, length: { maximum: 255 }, allow_blank: true
  validates :method, length: { maximum: 10 }, allow_blank: true

  scope :recent, -> { order(created_on: :desc) }
  scope :successes, -> { where(success: true) }
  scope :failures, -> { where(success: false) }
  scope :web_logins, -> { where(api: false) }
  scope :api_access, -> { where(api: true) }

  API_FORMAT = 'json'

  # ログイン元の種別
  def source
    api? ? 'api' : 'web'
  end

  # ログイン成功を記録
  def self.success(user, request, params = {})
    log(user, true, request, params) if log_success?
  end

  # ログイン失敗を記録
  def self.failure(user, request, params = {})
    log(user, false, request, params) if log_failure?
  end

  # ログ記録の本体
  def self.log(user, success, request, params)
    login = determine_login(user, params)
    user_id = user&.id || 'N/A'
    api = api_request?(request)

    audit = new(
      user: user,
      ip_address: request.remote_ip,
      success: success,
      login: login,
      api: api,
      url: request.fullpath,
      method: request.request_method,
      referer: request.referer,
      created_on: Time.current
    )

    begin
      audit.save!
      Rails.logger.info "LoginAudit: Saved for User:'#{login}', id: #{user_id}, Success: #{success}"
    rescue StandardError => e
      Rails.logger.error "LoginAudit: Failed to save for User:'#{login}', id: #{user_id}, Success: #{success}, Error: #{e.message}"
    ensure
      # Logged after the save, so the URL has been through the filters (API key, OAuth code)
      Rails.logger.info "LoginAudit Event: #{audit}"
    end
  end

  # 成功ログを記録するか
  def self.log_success?
    setting = plugin_setting('log_setting').to_i
    LoggingSetting.log_success_status.include?(setting)
  end

  # 失敗ログを記録するか
  def self.log_failure?
    setting = plugin_setting('log_setting').to_i
    LoggingSetting.log_failure_status.include?(setting)
  end

  def to_s
    user_info = user ? user.id : 'Unknown'
    action = api? ? 'call API' : 'login'
    result = success? ? 'Succeeded' : 'Failed'
    "LoginAudit(User #{user_info} with Login:#{login} IP:#{ip_address} #{result} to #{action} at #{url})"
  end

  # 古いログを削除
  def self.purge_old_records(months)
    older_than = months.months.ago
    delete_all(['created_on < ?', older_than])
  end

  # ログ設定クラス
  class LoggingSetting
    NOTHING   = 0
    SUCCESSES = 1
    FAILURES  = 2
    BOTH      = 3

    KEYS = [NOTHING, SUCCESSES, FAILURES, BOTH].freeze

    NAMES = {
      NOTHING   => 'nothing',
      SUCCESSES => 'successes',
      FAILURES  => 'failures',
      BOTH      => 'both'
    }.freeze

    class << self
      def to_dropdown
        KEYS.map { |k| [get_name(k), k] }
      end

      def log_success_status
        [SUCCESSES, BOTH]
      end

      def log_failure_status
        [FAILURES, BOTH]
      end

      def get_name(key)
        name = NAMES[key]
        I18n.t(name, scope: 'settings.logging', default: name&.capitalize)
      end
    end
  end

  private

  # URLが長すぎる場合は切り詰め
  def truncate_url
    return unless url

    self.url = url.truncate(255, separator: nil, omission: '[...]')
  end

  def truncate_referer
    return unless referer
    self.referer = referer.truncate(255, separator: nil, omission: '[...]')
  end

  def filter_out_api_key
    return unless plugin_setting('audit_api_filter_out_keys')

    if url
      self.url = url.sub(/key=[^&]+/, 'key=[FILTERED]')
    end
    if referer
      self.referer = referer.sub(/key=[^&]+/, 'key=[FILTERED]')
    end
  end

  # An OAuth/OIDC callback carries the authorization code and the CSRF state. Both are single-use and already spent
  # by the time this is written, but an audit trail has no use for them.
  OAUTH_PARAMS = /([?&](?:code|state|session_state)=)[^&]+/

  def filter_out_oauth_params
    self.url = url.gsub(OAUTH_PARAMS, '\1[FILTERED]') if url
    self.referer = referer.gsub(OAUTH_PARAMS, '\1[FILTERED]') if referer
  end

  def plugin_setting(key)
    self.class.plugin_setting(key)
  end

  class << self
    def plugin_setting(key)
      settings = Setting.plugin_redmine_login_audit2
      settings.is_a?(Hash) ? settings[key] : nil
    end

    def determine_login(user, params)
      return user.login if user

      params.is_a?(Hash) ? (params['username'] || params[:username] || 'Unknown') : 'Unknown'
    end

    def api_request?(request)
      request.format.to_s == API_FORMAT || request.format.to_s == 'application/json'
    end
  end
end
