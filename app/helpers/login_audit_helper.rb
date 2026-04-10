# frozen_string_literal: true

module LoginAuditHelper
  # パージ用の月数選択肢
  def choices_for_purge
    (1..12).map { |i| [l(:label_x_months, count: i), i] }
  end

  # 成功/失敗アイコン
  def success_icon(success)
    if success
      content_tag(:span, '✓', class: 'icon-only icon-checked', title: l(:general_text_Yes))
    else
      content_tag(:span, '✗', class: 'icon-only icon-not-checked', title: l(:general_text_No))
    end
  end

  # ソースラベル（API/Web）
  def source_label(audit)
    if audit.api?
      content_tag(:span, 'API', class: 'badge badge-api')
    else
      content_tag(:span, 'Web', class: 'badge badge-web')
    end
  end

  # フィルター用の成功/失敗選択肢
  def options_for_success_filter
    [
      [l(:label_all), ''],
      [l(:general_text_Yes), '1'],
      [l(:general_text_No), '0']
    ]
  end

  # フィルター用のAPI/Web選択肢
  def options_for_api_filter
    [
      [l(:label_all), ''],
      ['API', '1'],
      ['Web', '0']
    ]
  end
end
