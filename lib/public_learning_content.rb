require "json"

# 確認済みの固定ファイルを登録する。実行時のAI生成・既存内容の上書きはしない。
class PublicLearningContent
  class ContentMismatch < StandardError; end
  PATH = Rails.root.join("db/data/questions_v1.json")
  CODES = %w[r m s].flat_map { |prefix| (1..5).map { |number| "bs-#{prefix}#{number}" } }.freeze
  ACCOUNTS = [ [ "現金", "asset" ], [ "在庫", "asset" ], [ "設備", "asset" ], [ "借入金", "liability" ], [ "資本金", "equity" ] ].freeze
  DEMO_CODES = (1..3).flat_map { |industry| (1..5).map { |number| "demo-#{industry}-#{number}" } }.freeze

  def self.load!(data: JSON.parse(PATH.read))
    new(data).load!
  end

  def initialize(data)
    @data = data
  end

  def load!
    validate_file!
    ApplicationRecord.transaction do
      # 同時に登録コマンドを実行しても同じ問題を二重作成しない（PostgreSQL）。
      ApplicationRecord.connection.execute("SELECT pg_advisory_xact_lock(20261017, 35)")
      accounts = @data.fetch("accounts").map { |attributes| Account.find_or_create_by!(attributes) }
      @data.fetch("questions").each { |definition| register!(definition, accounts) }
      # 出題対象だけを切り替える。過去の問題と回答は残す。
      Question.available.where(code: DEMO_CODES).find_each(&:retire!)
    end
  end

  private

  def validate_file!
    definitions = @data.fetch("questions")
    raise ContentMismatch, "問題ファイルの形式・科目を確認してください" unless @data["format_version"] == 1 &&
      @data.fetch("accounts").map { |account| account.values_at("name", "category") } == ACCOUNTS
    raise ContentMismatch, "3業種各5問が必要です" unless definitions.map { |item| item["code"] }.sort == CODES.sort &&
      definitions.group_by { |item| item["industry"] }.transform_values(&:size) == Industry::NAMES.index_with { 5 }
    definitions.each do |item|
      valid = item["version"] == 1 && item.fetch("sheets").size == 2 && item.fetch("choices").size == 3
      valid &&= item.fetch("choices").all? { |choice| [ true, false ].include?(choice["is_correct"]) }
      valid &&= item.fetch("sheets").all? do |sheet|
        values = sheet.fetch("amounts")
        values.size == ACCOUNTS.size && values.all? { |value| value.is_a?(Integer) && value >= 0 }
      end
      raise ContentMismatch, "#{item['code']} の版・選択肢・BS金額を確認してください" unless valid
    end
  end

  def register!(definition, accounts)
    attributes = definition.slice("code", "version", "kind", "title", "body", "explanation")
      .merge("assumptions" => @data.fetch("assumptions"))
    industry = Industry.find_or_create_by!(name: definition.fetch("industry"))
    existing = Question.find_by(code: definition.fetch("code"), version: definition.fetch("version"))
    if existing
      verify_existing!(existing, definition, attributes, accounts, industry)
      return # 出題終了済みの版も再公開しない。
    end
    question = Question.create!(attributes.merge("industry" => industry))
    definition.fetch("choices").each_with_index do |choice, index|
      question.choices.create!(choice.merge("position" => index + 1))
    end
    definition.fetch("sheets").each_with_index do |sheet, index|
      record = question.balance_sheets.create!(sheet.slice("company_name", "business_description").merge("position" => index + 1))
      accounts.zip(sheet.fetch("amounts")).each do |account, amount|
        record.balance_sheet_items.create!(account: account, amount: amount)
      end
    end
    question.publish! # 貸借一致・選択肢3件・正解1件の検証を通してから出題対象にする。
  end

  def verify_existing!(question, definition, attributes, accounts, industry)
    choices = question.choices.map { |choice| choice.attributes.slice("body", "is_correct") }
    sheets = question.balance_sheets.map do |sheet|
      items = sheet.balance_sheet_items.index_by(&:account_id)
      sheet.attributes.slice("company_name", "business_description").merge(
        "amounts" => accounts.map { |account| items.fetch(account.id).amount }, "item_count" => items.size)
    end
    expected_sheets = definition.fetch("sheets").map { |sheet| sheet.merge("item_count" => accounts.size) }
    unless question.published_at.present? && question.industry == industry &&
        question.attributes.slice(*attributes.keys) == attributes && choices == definition.fetch("choices") && sheets == expected_sheets
      raise ContentMismatch, "#{question.code} は登録済みの内容と異なります。上書きせず、新しい版として改訂してください"
    end
  end
end
