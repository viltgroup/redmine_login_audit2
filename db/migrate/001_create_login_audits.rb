# frozen_string_literal: true

class CreateLoginAudits < ActiveRecord::Migration[7.2]
  def up
    # 既存テーブル（旧 redmine_login_audit）がある場合はスキップ
    if table_exists?(:login_audits)
      Rails.logger.info "LoginAudit: Table 'login_audits' already exists. Skipping creation."
      
      # 既存テーブルに不足カラムがあれば追加
      ensure_column_exists(:login_audits, :method, :string, limit: 10)
      
      # 既存インデックスの確認・追加
      add_index_if_not_exists(:login_audits, :created_on)
      add_index_if_not_exists(:login_audits, :success)
      add_index_if_not_exists(:login_audits, :login)
      
      return
    end

    create_table :login_audits do |t|
      t.references :user, foreign_key: true, index: true
      t.string :ip_address, limit: 45  # IPv6対応
      t.boolean :success, default: false, null: false
      t.string :login, limit: 255
      t.boolean :api, default: false, null: false
      t.string :url, limit: 255
      t.string :method, limit: 10
      t.datetime :created_on, null: false
    end

    add_index :login_audits, :created_on
    add_index :login_audits, :success
    add_index :login_audits, :login
  end

  def down
    # 旧プラグインのデータを保持したい場合があるので、
    # テーブル削除はコメントアウト
    # drop_table :login_audits
    Rails.logger.info "LoginAudit: Table 'login_audits' was NOT dropped to preserve data."
    Rails.logger.info "LoginAudit: Run 'DROP TABLE login_audits;' manually if you want to remove it."
  end

  private

  def ensure_column_exists(table, column, type, options = {})
    unless column_exists?(table, column)
      add_column table, column, type, **options
      Rails.logger.info "LoginAudit: Added column '#{column}' to '#{table}'."
    end
  end

  def add_index_if_not_exists(table, column)
    unless index_exists?(table, column)
      add_index table, column
      Rails.logger.info "LoginAudit: Added index on '#{table}.#{column}'."
    end
  end
end
