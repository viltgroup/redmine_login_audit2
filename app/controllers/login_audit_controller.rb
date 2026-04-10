# frozen_string_literal: true

class LoginAuditController < ApplicationController
  layout 'admin'

  before_action :require_admin
  before_action :find_audit, only: [:show]

  helper :sort
  include SortHelper

  def index
    sort_init 'created_on', 'desc'
    sort_update %w[created_on login ip_address success api method]

    per_page = Setting.plugin_redmine_login_audit2['audit_rows_per_page'].to_i
    per_page = 50 if per_page <= 0

    scope = LoginAudit.all

    # フィルター適用
    scope = apply_filters(scope)

    @audit_count = scope.count
    @audit_pages = Paginator.new(@audit_count, per_page, params['page'])
    @audits = scope
                .order(sort_clause)
                .limit(@audit_pages.per_page)
                .offset(@audit_pages.offset)
                .preload(:user)
                .to_a
    # 一番古いログを取得（パージ画面の表示用）
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
    scope = LoginAudit.all
    scope = apply_filters(scope)
    # .to_a を削除し、ActiveRecord::Relation のままにしておく
    @audits = scope.order(created_on: :desc).preload(:user)

    filename = "login_audit_#{Date.today}.csv"

    # HTTPヘッダを設定し、ブラウザにダウンロードを促す（ストリーミング準備）
    headers['X-Accel-Buffering'] = 'no' # Nginx等のバッファリングを無効化
    headers['Cache-Control'] = 'no-cache'
    headers['Content-Type'] = 'text/csv; charset=utf-8'
    headers['Content-Disposition'] = %(attachment; filename="#{filename}")
    headers['Last-Modified'] = Time.current.httpdate

    # Enumeratorを使って、データを逐次生成しながらレスポンスとして返す
    self.response_body = Enumerator.new do |yielder|
      require 'csv'

      # 1. まずBOM(UTF-8)を出力する場合（Excel文字化け対策: 必要に応じて）
      # yielder << "\xEF\xBB\xBF"

      # 2. ヘッダー行を出力
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

      # 3. データを1000件ずつ取得して出力（find_eachによるバッチ処理）
      @audits.find_each(batch_size: 1000) do |audit|
        yielder << CSV.generate_line([
          format_time(audit.created_on),
          audit.login,
          audit.user&.name,
          audit.ip_address,
          audit.success? ? l(:general_text_Yes) : l(:general_text_No),
          audit.source,
          audit.method,
          audit.url
        ])
      end
    end
  end

  private

  def find_audit
    @audit = LoginAudit.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def apply_filters(scope)
    # ログインIDでフィルター
    if params[:login].present?
      scope = scope.where('login LIKE ?', "%#{params[:login]}%")
    end

    # IPアドレスでフィルター
    if params[:ip_address].present?
      scope = scope.where('ip_address LIKE ?', "%#{params[:ip_address]}%")
    end

    # 成功/失敗でフィルター
    if params[:success].present? && params[:success] != ''
      scope = scope.where(success: params[:success] == '1')
    end

    # API/Webでフィルター
    if params[:api].present? && params[:api] != ''
      scope = scope.where(api: params[:api] == '1')
    end

    # 日付範囲でフィルター
    if params[:from_date].present?
      scope = scope.where('created_on >= ?', params[:from_date].to_date.beginning_of_day)
    end

    if params[:to_date].present?
      scope = scope.where('created_on <= ?', params[:to_date].to_date.end_of_day)
    end

    scope
  end

end
