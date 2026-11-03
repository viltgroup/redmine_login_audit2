# db/migrate/003_create_login_audit_attempts.rb
class CreateLoginAuditAttempts < ActiveRecord::Migration[7.2]
  def change
    create_table :login_audit_attempts do |t|
      t.string :login, limit: 255, null: false
      t.integer :failed_count, default: 0, null: false
      t.datetime :last_failed_at, null: false
    end
    add_index :login_audit_attempts, :login, unique: true
    add_index :login_audit_attempts, :last_failed_at
  end
end
