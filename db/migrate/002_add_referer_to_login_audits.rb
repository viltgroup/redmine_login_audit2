# db/migrate/002_add_referer_to_login_audits.rb
class AddRefererToLoginAudits < ActiveRecord::Migration[7.2]
  def change
    add_column :login_audits, :referer, :string, limit: 255
  end
end