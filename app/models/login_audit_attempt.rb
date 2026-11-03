# frozen_string_literal: true

# Failed password attempts per login name, for the attempts limit. Kept in the database rather than in process memory
# so that every application node and worker sees the same count, and a restart does not reset it.
#
# Login names are counted whether or not an account exists, so a block says nothing about which accounts do. Failures
# further apart than the block duration are not added up, and a block ends that long after the last failure.
class LoginAuditAttempt < ActiveRecord::Base
  scope :blocking, lambda {
    where('last_failed_at > ?', RedmineLoginAudit2.block_minutes.minutes.ago)
      .where('failed_count >= ?', RedmineLoginAudit2.attempts_limit)
  }

  def self.normalize(login)
    # Matches how core looks accounts up: stripped and case-insensitive
    login.to_s.strip.downcase.first(255)
  end

  # Counts an attempt before its password is checked, and returns false instead if the login name is blocked. Checking
  # first and counting after let concurrent requests all pass the check before any of them counted: twelve at once got
  # six passwords checked against a limit of three. Under the row lock the request that would exceed the limit waits
  # for the others and then sees the block. A successful login clears the count again
  def self.take_attempt(login)
    key = normalize(login)
    return true if key.blank?

    now = Time.current
    taken = false
    begin
      transaction do
        attempt = lock.find_or_initialize_by(login: key)
        next if attempt.blocking?(now)

        attempt.failed_count = attempt.expired?(now) ? 1 : attempt.failed_count + 1
        attempt.last_failed_at = now
        attempt.save!
        taken = true
      end
    rescue ActiveRecord::RecordNotUnique
      # Another request inserted the same login first; the row exists now, so the locked read finds it
      retry
    end
    where('last_failed_at <= ?', now - RedmineLoginAudit2.block_minutes.minutes).delete_all if taken
    taken
  end

  # Returns an attempt that never reached a password check (an LDAP outage)
  def self.give_back(login)
    where(login: normalize(login)).where('failed_count > 0').update_all('failed_count = failed_count - 1')
  end

  def self.clear(login)
    where(login: normalize(login)).delete_all
  end

  def expired?(now = Time.current)
    last_failed_at.nil? || last_failed_at <= now - RedmineLoginAudit2.block_minutes.minutes
  end

  def blocking?(now = Time.current)
    !expired?(now) && failed_count >= RedmineLoginAudit2.attempts_limit
  end

  def blocked_until
    last_failed_at + RedmineLoginAudit2.block_minutes.minutes
  end
end
