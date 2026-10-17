module QuizzesHelper
  CATEGORY_LABELS = { "asset" => "資産", "liability" => "負債", "equity" => "純資産" }.freeze

  def yen(amount)
    "#{number_with_delimiter(amount)}円"
  end

  def asset_percentage(amount, sheet)
    number_to_percentage(amount.fdiv(sheet.total("asset")) * 100, precision: 1)
  end

  def sheet_segments(sheet, side, maximum)
    categories = side == :assets ? [ "asset" ] : %w[liability equity]
    items = categories.flat_map do |category|
      sheet.balance_sheet_items.select { |item| item.account.category == category }.sort_by(&:account_id)
    end
    offset = 210 - items.sum(&:amount).fdiv(maximum) * 180
    items.map do |item|
      height = item.amount.fdiv(maximum) * 180
      segment = { item: item, y: offset, height: height, category: item.account.category }
      offset += height
      segment
    end
  end

  def transaction_changes(sheets)
    before, after = sheets.map { |sheet| sheet.balance_sheet_items.index_by(&:account_id) }
    (before.keys | after.keys).sort.filter_map do |id|
      change = (after[id]&.amount || 0) - (before[id]&.amount || 0)
      next if change.zero?
      "#{(before[id] || after[id]).account.name}：#{yen(change.abs)}#{change.positive? ? '増加' : '減少'}"
    end
  end
end
