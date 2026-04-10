# Redmine Login Audit 2

A login audit plugin for Redmine 6.x.

This is a refactored version of the original [redmine_login_audit](https://github.com/martin-denizet/redmine_login_audit) by Martin Denizet, updated for Redmine 6.x / Rails 7.2.

## Features

- **Web Login Logging**: Records successful and failed login attempts
- **API Access Logging**: Tracks REST API authentication
- **SAML/SSO Support**: Captures failed logins for locked users via SSO (e.g., Okta, KeyCloak)
- **Admin Interface**: View logs with filtering, sorting, and CSV export
- **Log Purging**: Bulk deletion of old records with safety confirmation

## Requirements

- Redmine 6.0 or higher
- Ruby 3.2 or higher
- Rails 7.2

## Installation

### Fresh Install

```bash
cd /path/to/redmine/plugins
git clone https://github.com/seraph3000/redmine_login_audit2.git
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Restart Redmine after installation.

### Migration from redmine_login_audit

To migrate from the original `redmine_login_audit` plugin while preserving existing data:

```bash
# 1. Remove old plugin (table remains)
cd /path/to/redmine
rm -rf plugins/redmine_login_audit

# 2. Install new plugin
cd plugins
git clone https://github.com/seraph3000/redmine_login_audit2.git

# 3. Check migration status
cd /path/to/redmine
bundle exec rake redmine_login_audit2:check RAILS_ENV=production

# 4. Run migration (preserves existing data)
bundle exec rake redmine_login_audit2:migrate_from_v1 RAILS_ENV=production

# 5. Restart Redmine
touch tmp/restart.txt

# 6. (Optional) Clean up old migration records
bundle exec rake redmine_login_audit2:cleanup_v1 RAILS_ENV=production
```

### Available Rake Tasks

| Task | Description |
|------|-------------|
| `redmine_login_audit2:check` | Check current migration status |
| `redmine_login_audit2:migrate_from_v1` | Migrate from old plugin |
| `redmine_login_audit2:cleanup_v1` | Remove old migration records |
| `redmine_login_audit2:stats` | Show statistics |
| `redmine_login_audit2:purge MONTHS=6` | Delete old logs |

## Uninstall

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate NAME=redmine_login_audit2 VERSION=0 RAILS_ENV=production
rm -rf plugins/redmine_login_audit2
```

## Configuration

Navigate to "Administration" → "Plugins" → "Redmine Login Audit 2" → "Configure":

| Setting | Description |
|---------|-------------|
| Logging Setting | Nothing / Successes only / Failures only / Both |
| Audit API | Also log REST API access |
| Filter API Keys | Replace API keys in URL with [FILTERED] |
| Rows per Page | Number of entries per page in admin view |

## Usage

Access logs via "Administration" → "Login Audit".

### Filtering

- Login ID
- IP Address
- Success / Failure
- Web / API
- Date range

### Log Deletion

- Delete logs older than specified months (displays oldest log date for reference)
- Delete all logs (requires checkbox confirmation to prevent accidental deletion)

## Changes from Original

### Removed Features

- Email notification (unnecessary in SSO environments)
- wice_grid dependency (replaced with standard Redmine pagination)

### Technical Changes

- `alias_method_chain` → `prepend` pattern
- `before_filter` → `before_action`
- `attr_accessible` → Removed (Strong Parameters)
- `unloadable` → Removed

### New Features

- **SAML/SSO Support**: Properly logs failed authentication for locked/disabled users via SSO
- **Streaming CSV Export**: Memory-efficient export using batch processing (1,000 records at a time)
- **Improved Purge UI**: Displays oldest log date, collapsible section for cleaner interface
- **Delete All Protection**: Requires checkbox confirmation to prevent accidental deletion
- **HTML5 Date Picker**: Native date input fields (no calendar helper dependency)

## Supported Authentication Methods

| Method | Success | Failure | Notes |
|--------|:-------:|:-------:|-------|
| Redmine Standard Login | ✓ | ✓ | Built-in |
| LDAP / Active Directory | ✓ | ✓ | Uses standard `try_to_login` |
| REST API (key/basic auth) | ✓ | ✓ | Built-in |
| SAML (redmine_saml) | ✓ | ✓ | Built-in |
| Other OmniAuth plugins | ✓ | — | Success via hook; failure requires extension |

**Success logging** works automatically for all authentication methods via Redmine's `controller_account_success_authentication_after` hook.

**Failure logging** for OmniAuth-based plugins (OAuth2, OpenID Connect, etc.) requires explicit support because each plugin handles callbacks differently.

## Extending for Other OmniAuth Plugins

If you use an OmniAuth-based authentication plugin not listed above, you can add failure logging support by modifying `lib/redmine_login_audit2/account_controller_patch.rb`.

### Step 1: Identify the Callback Method

Check your authentication plugin's source code for the callback method name. Common patterns:

| Plugin | Callback Method |
|--------|-----------------|
| redmine_saml | `login_with_saml_callback` |
| redmine_omniauth_google | `oauth_google_callback` |
| redmine_omniauth_github | `oauth_github_callback` |
| redmine_omniauth_azure | `oauth_azure_callback` |
| redmine_openid_connect | `oic_callback` |

### Step 2: Add the Override

Add a method to `account_controller_patch.rb` following this pattern:

```ruby
# Example: Adding support for redmine_omniauth_google
def oauth_google_callback
  auth = request.env['omniauth.auth']

  if auth.present?
    user = User.find_or_create_from_omniauth(auth)

    if user.blank?
      # User not found or could not be created
      LoginAudit.failure(nil, request, { username: auth[:uid] || auth.info&.email })
    elsif !user.active?
      # User exists but is locked/disabled
      Rails.logger.info "LoginAudit: User '#{user.login}' is not active (status=#{user.status})"
      LoginAudit.failure(user, request, { username: user.login })
    end
    # Success is recorded automatically via the hook
  end

  super
end
```

### Step 3: (Optional) Add Plugin Detection

For cleaner code, add a detection method to `lib/redmine_login_audit2.rb`:

```ruby
def google_oauth_plugin_installed?
  Redmine::Plugin.installed?(:redmine_omniauth_google)
rescue
  false
end
```

Then wrap your callback:

```ruby
def oauth_google_callback
  unless RedmineLoginAudit2.google_oauth_plugin_installed?
    return super if defined?(super)
    return render_404
  end
  # ... rest of the code
  super
end
```

### Key Points

1. **Always call `super`** at the end to let the original plugin handle the actual authentication
2. **Check `user.active?`** — SSO can return locked users who pass external auth but should fail in Redmine
3. **Use `auth[:uid]`** or `auth.info.email` for username when user is nil
4. **Don't record success** — the hook handles it automatically for active users

### Troubleshooting

If failure logging doesn't work:

1. **Check the callback method name** — Use `grep -r "def.*callback" plugins/redmine_omniauth_*` to find it
2. **Check if `find_or_create_from_omniauth` exists** — Some plugins use different methods like `find_by_provider_and_uid`
3. **Enable debug logging** — Add `Rails.logger.debug` statements to trace execution
4. **Verify plugin load order** — This plugin should load after the auth plugin (alphabetical order usually works)

## License

MIT License

## Credits

- Original Author: Martin Denizet
- Refactored by: seraph3000
