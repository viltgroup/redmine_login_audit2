# frozen_string_literal: true

class LoginAuditController < ApplicationController
  layout 'admin'

  before_action :require_admin
  before_action :find_audit, only: [:show]

  helper :sort
  include SortHelper
  helper :queries
  include QueriesHelper

  def index
    retrieve_login_audit_query
    sort_init 'created_on', 'desc'
    sort_update %w[created_on login ip_address success api method]

    per_page = if params[:per_page].present?
                 params[:per_page].to_i
               else
                 Setting.plugin_redmine_login_audit2['audit_rows_per_page'].to_i
               end
    per_page = 25 if per_page <= 0

    scope = @query.results_scope

    @audit_count = scope.count
    @audit_pages = Paginator.new(@audit_count, per_page, params['page'])
    @audits = scope
                .reorder(sort_clause)
                .limit(@audit_pages.per_page)
                .offset(@audit_pages.offset)
                .to_a

    @oldest_audit = LoginAudit.order(created_on: :asc).first
  end

  def show
    # 個別詳細表示（必要に応じて）
  end

  # 指定月数より古いログを削除
  def delete
    purge_offset = params[:purge_offset].to_i

    if purge_offset > 0
      older_than = purge_offset.months.ago
      count = LoginAudit.where('created_on < ?', older_than).delete_all

      flash[:notice] = l(:notice_la_records_deleted, count: count.to_s, date: format_time(older_than))
    else
      flash[:error] = l(:error_la_bad_parameters)
    end

    redirect_to action: 'index'
  end

  # 全ログを削除
  def delete_all
    count = LoginAudit.delete_all

    flash[:notice] = l(:notice_la_records_all_deleted, count: count.to_s)

    redirect_to action: 'index'
  end

  # CSV エクスポート
  def export
    retrieve_login_audit_query
    @audits = @query.results_scope.reorder(created_on: :desc)

    filename = "login_audit_#{Date.today}.csv"

    headers['X-Accel-Buffering'] = 'no'
    headers['Cache-Control'] = 'no-cache'
    headers['Content-Type'] = 'text/csv; charset=utf-8'
    headers['Content-Disposition'] = %(attachment; filename="#{filename}")
    headers['Last-Modified'] = Time.current.httpdate

    self.response_body = Enumerator.new do |yielder|
      require 'csv'

      yielder << CSV.generate_line([
        l(:field_created_on),
        l(:field_login),
        l(:field_user),
        l(:field_ip_address),
        l(:field_success),
        l(:field_source),
        l(:field_method),
        l(:field_url)
      ])

      @audits.find_each(batch_size: 1000) do |audit|
        yielder << CSV.generate_line(csv_row_for(audit))
      end
    end
  end

  def stats
    retrieve_login_audit_query
    scope = @query.results_scope

    # created_on フィルタ指定の有無
    has_date_filter = @query.filters.key?('created_on')

    # 対象期間はデータの実範囲から取る
    @from_date = scope.minimum(:created_on)&.to_date
    @to_date   = scope.maximum(:created_on)&.to_date

    # 日別推移（created_on フィルタ指定なしなら直近30日に絞る）
    daily_scope = has_date_filter ? scope : scope.where('created_on >= ?', 30.days.ago)
    @daily_counts = daily_scope.group(Arel.sql("DATE(created_on)"))
                               .group(:success)
                               .count

    @success_count = scope.where(success: true).count
    @failure_count = scope.where(success: false).count
    @api_count     = scope.where(api: true).count
    @web_count     = scope.where(api: false).count

    @top_failure_ips = scope.where(success: false)
                            .group(:ip_address)
                            .order(Arel.sql("COUNT(*) DESC"))
                            .limit(10)
                            .count

    @top_failure_logins = scope.where(success: false)
                               .group(:login)
                               .order(Arel.sql("COUNT(*) DESC"))
                               .limit(10)
                               .count
  end

  private

  def find_audit
    @audit = LoginAudit.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # フィルタ付き Query を組み立てて @query にセットする。
  def retrieve_login_audit_query
    @query = LoginAuditQuery.new(name: '_')
    @query.build_from_params(params)
    @query
  end

  def safe_csv_cell(value)
    str = value.to_s
    str.match?(/\A[=+\-@]/) ? "'#{str}" : str
  end

  def csv_row_for(audit)
    [
      format_time(audit.created_on),
      safe_csv_cell(audit.login),
      safe_csv_cell(audit.user&.name),
      safe_csv_cell(audit.ip_address),
      audit.success? ? l(:general_text_Yes) : l(:general_text_No),
      safe_csv_cell(audit.source),
      safe_csv_cell(audit.method),
      safe_csv_cell(audit.url)
    ]
  end
end