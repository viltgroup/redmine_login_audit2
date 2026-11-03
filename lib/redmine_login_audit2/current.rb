# frozen_string_literal: true

module RedmineLoginAudit2
  # Per request state. The attempts limit refuses a login in the User model, where there is no request, and the
  # controllers read this to tell a blocked login apart from a wrong password. Rails resets it after every request
  class Current < ActiveSupport::CurrentAttributes
    attribute :login_blocked
  end
end
