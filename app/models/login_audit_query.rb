# frozen_string_literal: true

# =====================================================================
# Redmine Login Audit 2
# login_audit_query.rb
#
# Redmine 標準の Query を継承し、ログイン監査ログのフィルタ／表示を
# コア標準のフィルタUIに委譲する。6.0 / 6.1 / 7.0 共通。
# =====================================================================

class LoginAuditQuery < Query
  self.queried_class = LoginAudit

  self.available_columns = [
    QueryColumn.new(:created_on, sortable: "#{LoginAudit.table_name}.created_on", default_order: 'desc'),
    QueryColumn.new(:login,      sortable: "#{LoginAudit.table_name}.login"),
    QueryColumn.new(:user),
    QueryColumn.new(:ip_address, sortable: "#{LoginAudit.table_name}.ip_address"),
    QueryColumn.new(:success,    sortable: "#{LoginAudit.table_name}.success"),
    QueryColumn.new(:api,        sortable: "#{LoginAudit.table_name}.api"),
    QueryColumn.new(:method,     sortable: "#{LoginAudit.table_name}.method"),
    QueryColumn.new(:url),
  ]

  def initialize(attributes = nil, *args)
    super(attributes)
    self.filters ||= {}
  end

  # 管理者専用（コントローラの require_admin で保護）
  def initialize_available_filters
    add_available_filter 'login',      type: :string
    add_available_filter 'ip_address', type: :string
    add_available_filter 'success',
                         type: :list,
                         values: [
                           [l(:general_text_Yes), '1'],
                           [l(:general_text_No),  '0']
                         ]
    add_available_filter 'api',
                         type: :list,
                         values: [
                           [l(:label_source_web), '0'],
                           [l(:label_source_api), '1']
                         ]
    add_available_filter 'created_on', type: :date_past
    add_available_filter 'method',     type: :string
    add_available_filter 'url',        type: :string
  end

  # 検索結果の Relation を返す（コア基底には無い。IssueQuery 等に倣い自前定義）
  def results_scope(options = {})
    order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

    LoginAudit
      .where(statement)
      .order(order_option)
      .preload(:user)
  end

  def label_for(field)
    case field.to_s
    when 'login'      then l(:field_login)
    when 'ip_address' then l(:field_ip_address)
    when 'success'    then l(:field_success)
    when 'api'        then l(:field_source)
    when 'created_on' then l(:field_created_on)
    when 'method'     then l(:field_method)
    when 'url'        then l(:field_url)
    else super
    end
  end
end