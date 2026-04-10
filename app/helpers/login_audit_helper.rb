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

  # 横棒グラフ1行分
  def bar_row(label, value, max_value, color_class = 'bar-success')
    pct = max_value > 0 ? (value.to_f / max_value * 100).round(1) : 0
    content_tag(:div, class: 'bar-row') do
      content_tag(:span, label, class: 'bar-label') +
      content_tag(:div, class: 'bar-track') do
        content_tag(:div, value.to_s, class: "bar-fill #{color_class}",
                    style: "width: #{pct}%")
      end
    end
  end

  # 円グラフ（conic-gradient）
  def pie_chart(slices)
    # slices = [{ value: 72, color: '#4caf50', label: '成功' }, ...]
    total = slices.sum { |s| s[:value] }
    return content_tag(:div, '-', class: 'pie-empty') if total == 0

    cumulative = 0
    stops = slices.map do |s|
      pct = (s[:value].to_f / total * 100).round(2)
      from = cumulative
      cumulative += pct
      "#{s[:color]} #{from}% #{cumulative}%"
    end

    content_tag(:div, '', class: 'pie-chart',
                style: "background: conic-gradient(#{stops.join(', ')})") +
    content_tag(:ul, class: 'pie-legend') do
      safe_join(slices.map { |s|
        pct = (s[:value].to_f / total * 100).round(1)
        content_tag(:li) do
          content_tag(:span, '', class: 'legend-color',
                      style: "background: #{s[:color]}") +
          " #{s[:label]}: #{s[:value]} (#{pct}%)"
        end
      })
    end
  end
end
