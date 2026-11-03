# frozen_string_literal: true

module RedmineLoginAudit2
  module UserPatch
    def self.prepended(base)
      base.singleton_class.prepend(ClassMethods)
      base.after_save :clear_login_attempts, if: :saved_change_to_hashed_password?
    end

    module ClassMethods
      # Every password check goes through here: the login form, HTTP Basic on the API, and other plugins' Basic
      # authentication (redmine_mcp_plugin). A blocked login is refused before the password is checked, so it is not
      # tried against LDAP either. An LDAP outage raises from here and is not counted as a failure
      def try_to_login!(login, password, active_only = true)
        return super unless RedmineLoginAudit2.attempts_limit_enabled?
        # Core tries HTTP Basic credentials as a login first and as an API key second, so a valid key arrives here
        # as a login name. It is no attempt on a password, and the key must not be stored
        return super if api_key_shaped?(login) && find_by_api_key(login.to_s)

        unless LoginAuditAttempt.take_attempt(login)
          RedmineLoginAudit2::Current.login_blocked = true
          return nil
        end

        user = begin
          super
        rescue AuthSourceException
          LoginAuditAttempt.give_back(login)
          raise
        end
        LoginAuditAttempt.clear(login) if user
        user
      end

      private

      # Core's API keys are 40 hex characters; anything else needs no lookup
      def api_key_shaped?(login)
        login.to_s.match?(/\A\h{40}\z/)
      end
    end

    private

    # A new password, from a password reset or an administrator, ends the block
    def clear_login_attempts
      LoginAuditAttempt.clear(login)
    end
  end
end
