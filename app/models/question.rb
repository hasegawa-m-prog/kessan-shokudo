class Question < ApplicationRecord
  belongs_to :industry
  has_many :choices, -> { order(:position) }, dependent: :restrict_with_error
  has_many :balance_sheets, -> { order(:position) }, dependent: :restrict_with_error
  has_many :quiz_run_questions, dependent: :restrict_with_error
  validates :code, :title, :body, :assumptions, :explanation, presence: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :code }
  validates :kind, inclusion: { in: %w[company_comparison transaction] }
  validate :protect_published_content
  validate :check_publication, if: -> { published_at.present? && published_at_in_database.nil? }
  before_destroy :prevent_published_destruction

  scope :available, -> { where(retired_at: nil).where("published_at <= ?", Time.current) }
  scope :with_diagrams, -> { includes(:choices, balance_sheets: { balance_sheet_items: :account }) }

  def publish!
    with_lock { update!(published_at: Time.current) }
  end

  def retire!
    with_lock { update!(retired_at: Time.current) }
  end

  def correct_choice
    choices.find(&:is_correct)
  end

  private

  def check_publication
    errors.add(:base, "選択肢は表示順1〜3の3件、正解は1件必要です") unless choices.map(&:position).sort == [ 1, 2, 3 ] && choices.count(&:is_correct) == 1
    sheets = balance_sheets.to_a
    errors.add(:base, "BSは表示順1・2の2件必要です") unless sheets.map(&:position).sort == [ 1, 2 ]
    sheets.each do |sheet|
      errors.add(:base, "#{sheet.company_name}の資産と負債・純資産が一致しません") unless sheet.balanced?
    end
    if kind == "transaction" && sheets.map(&:company_name).uniq.size != 1
      errors.add(:base, "取引前後は同じ会社名にしてください")
    end
    errors.add(:published_at, "に未来の日時は指定できません") if published_at > Time.current
  end

  def protect_published_content
    return if published_at_in_database.nil?
    forbidden = changes_to_save.keys - %w[retired_at updated_at]
    errors.add(:base, "公開済みの内容は変更できません。新しい版を作成してください") if forbidden.any?
    if retired_at_changed? && (retired_at_in_database.present? || retired_at.nil? || retired_at < published_at)
      errors.add(:retired_at, "は公開後の日時を一度だけ設定できます")
    end
  end

  def prevent_published_destruction
    return if published_at.nil?
    errors.add(:base, "公開済みの問題は削除できません")
    throw :abort
  end
end
