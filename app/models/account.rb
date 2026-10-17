class Account < ApplicationRecord
  has_many :balance_sheet_items, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: { scope: :category }
  validates :category, inclusion: { in: %w[asset liability equity] }
  validate :protect_used_account, on: :update

  private

  def protect_used_account
    if balance_sheet_items.joins(balance_sheet: :question).where.not(questions: { published_at: nil }).exists? && (name_changed? || category_changed?)
      errors.add(:base, "公開済みのBSで使用している科目は変更できません")
    end
  end
end
