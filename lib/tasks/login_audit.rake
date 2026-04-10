# frozen_string_literal: true

namespace :redmine_login_audit2 do
  desc 'Check migration status and existing data'
  task check: :environment do
    puts "=" * 60
    puts "Redmine Login Audit 2 - Migration Check"
    puts "=" * 60
    puts

    # テーブル存在確認
    table_exists = ActiveRecord::Base.connection.table_exists?(:login_audits)
    puts "[Table] login_audits: #{table_exists ? 'EXISTS' : 'NOT FOUND'}"

    if table_exists
      count = LoginAudit.count rescue 'ERROR'
      puts "[Data]  Record count: #{count}"
    end
    puts

    # マイグレーション状態確認
    puts "[Migration Records]"
    
    # 旧プラグイン
    old_migrations = ActiveRecord::Base.connection.select_values(
      "SELECT version FROM schema_migrations WHERE version LIKE '%-redmine_login_audit'"
    )
    if old_migrations.any?
      puts "  redmine_login_audit (OLD):"
      old_migrations.each { |v| puts "    - #{v}" }
    else
      puts "  redmine_login_audit (OLD): None"
    end

    # 新プラグイン
    new_migrations = ActiveRecord::Base.connection.select_values(
      "SELECT version FROM schema_migrations WHERE version LIKE '%-redmine_login_audit2'"
    )
    if new_migrations.any?
      puts "  redmine_login_audit2 (NEW):"
      new_migrations.each { |v| puts "    - #{v}" }
    else
      puts "  redmine_login_audit2 (NEW): None"
    end

    puts
    puts "[Recommendation]"
    if table_exists && old_migrations.any? && new_migrations.empty?
      puts "  -> Run: rake redmine_login_audit2:migrate_from_v1 RAILS_ENV=production"
      puts "     This will mark new plugin as migrated without recreating the table."
    elsif table_exists && new_migrations.any?
      puts "  -> Already migrated. No action needed."
    elsif !table_exists
      puts "  -> Fresh install. Run: rake redmine:plugins:migrate RAILS_ENV=production"
    else
      puts "  -> Run: rake redmine_login_audit2:migrate_from_v1 RAILS_ENV=production"
    end
    puts
  end

  desc 'Migrate from old redmine_login_audit plugin (preserves existing data)'
  task migrate_from_v1: :environment do
    puts "=" * 60
    puts "Redmine Login Audit 2 - Migration from v1"
    puts "=" * 60
    puts

    table_exists = ActiveRecord::Base.connection.table_exists?(:login_audits)

    unless table_exists
      puts "[ERROR] Table 'login_audits' does not exist."
      puts "        Run normal migration: rake redmine:plugins:migrate RAILS_ENV=production"
      exit 1
    end

    # 既にマイグレーション済みか確認
    already_migrated = ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM schema_migrations WHERE version = '1-redmine_login_audit2'"
    ).to_i > 0

    if already_migrated
      puts "[INFO] Already migrated to redmine_login_audit2."
      puts "       No action needed."
      exit 0
    end

    # 既存データ数を確認
    record_count = LoginAudit.count rescue 0
    puts "[INFO] Found #{record_count} existing records in login_audits table."
    puts

    # カラム確認・追加
    puts "[STEP 1] Checking table structure..."
    
    conn = ActiveRecord::Base.connection
    
    # methodカラムがなければ追加（旧バージョンにはない可能性）
    unless conn.column_exists?(:login_audits, :method)
      puts "  Adding 'method' column..."
      conn.add_column :login_audits, :method, :string, limit: 10
    else
      puts "  'method' column: OK"
    end

    # インデックス確認・追加
    puts
    puts "[STEP 2] Checking indexes..."
    
    [:created_on, :success, :login].each do |col|
      if conn.index_exists?(:login_audits, col)
        puts "  Index on '#{col}': OK"
      else
        puts "  Adding index on '#{col}'..."
        conn.add_index :login_audits, col
      end
    end

    # マイグレーションを「実行済み」としてマーク
    puts
    puts "[STEP 3] Marking migration as complete..."
    
    conn.execute(
      "INSERT INTO schema_migrations (version) VALUES ('1-redmine_login_audit2')"
    )
    puts "  Inserted: 1-redmine_login_audit2"

    puts
    puts "[SUCCESS] Migration complete!"
    puts "          Existing data preserved: #{record_count} records"
    puts
    puts "[NEXT STEPS]"
    puts "  1. Restart Redmine"
    puts "  2. Verify plugin works: Admin -> Login Audit"
    puts "  3. (Optional) Clean up old migration records:"
    puts "     rake redmine_login_audit2:cleanup_v1 RAILS_ENV=production"
    puts
  end

  desc 'Remove old redmine_login_audit migration records from schema_migrations'
  task cleanup_v1: :environment do
    puts "=" * 60
    puts "Redmine Login Audit 2 - Cleanup Old Migration Records"
    puts "=" * 60
    puts

    old_migrations = ActiveRecord::Base.connection.select_values(
      "SELECT version FROM schema_migrations WHERE version LIKE '%-redmine_login_audit'"
    )

    if old_migrations.empty?
      puts "[INFO] No old migration records found."
      exit 0
    end

    puts "[FOUND] Old migration records:"
    old_migrations.each { |v| puts "  - #{v}" }
    puts

    print "Delete these records? [y/N]: "
    confirm = ENV['FORCE'] == '1' ? 'y' : STDIN.gets.chomp.downcase

    if confirm == 'y'
      deleted = ActiveRecord::Base.connection.delete(
        "DELETE FROM schema_migrations WHERE version LIKE '%-redmine_login_audit'"
      )
      puts
      puts "[SUCCESS] Deleted #{deleted} old migration record(s)."
    else
      puts
      puts "[CANCELLED] No changes made."
      puts "            To force delete: rake redmine_login_audit2:cleanup_v1 FORCE=1"
    end
    puts
  end

  desc 'Show statistics'
  task stats: :environment do
    puts "=" * 60
    puts "Redmine Login Audit 2 - Statistics"
    puts "=" * 60
    puts

    unless ActiveRecord::Base.connection.table_exists?(:login_audits)
      puts "[ERROR] Table 'login_audits' does not exist."
      exit 1
    end

    total = LoginAudit.count
    successes = LoginAudit.where(success: true).count
    failures = LoginAudit.where(success: false).count
    web_logins = LoginAudit.where(api: false).count
    api_access = LoginAudit.where(api: true).count

    puts "Total records:    #{total}"
    puts "  Successes:      #{successes}"
    puts "  Failures:       #{failures}"
    puts "  Web logins:     #{web_logins}"
    puts "  API access:     #{api_access}"
    puts

    if total > 0
      oldest = LoginAudit.order(:created_on).first
      newest = LoginAudit.order(created_on: :desc).first
      puts "Date range:"
      puts "  Oldest: #{oldest.created_on}"
      puts "  Newest: #{newest.created_on}"
    end
    puts
  end

  desc 'Purge old records (MONTHS=6 to delete records older than 6 months)'
  task purge: :environment do
    months = (ENV['MONTHS'] || 6).to_i

    if months <= 0
      puts "[ERROR] Invalid MONTHS value. Use: MONTHS=6"
      exit 1
    end

    older_than = months.months.ago
    count = LoginAudit.where('created_on < ?', older_than).count

    puts "=" * 60
    puts "Redmine Login Audit 2 - Purge Old Records"
    puts "=" * 60
    puts
    puts "Records older than #{months} months (before #{older_than}): #{count}"
    puts

    if count == 0
      puts "[INFO] No records to delete."
      exit 0
    end

    print "Delete these #{count} records? [y/N]: "
    confirm = ENV['FORCE'] == '1' ? 'y' : STDIN.gets.chomp.downcase

    if confirm == 'y'
      deleted = LoginAudit.where('created_on < ?', older_than).delete_all
      puts
      puts "[SUCCESS] Deleted #{deleted} record(s)."
    else
      puts
      puts "[CANCELLED] No changes made."
      puts "            To force delete: rake redmine_login_audit2:purge MONTHS=#{months} FORCE=1"
    end
    puts
  end
end
