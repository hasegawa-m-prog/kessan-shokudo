class BalanceSheet < ApplicationRecord
  include PublishedContent
  belongs_to :question
  has_many :balance_sheet_items, dependent: :restrict_with_error
  validates :company_name, :business_description, presence: true
  validates :position, inclusion: { in: 1..2 }, uniqueness: { scope: :question_id }

  def total(category)
    balance_sheet_items.select { |item| item.account.category == category }.sum(&:amount)
  end

  def balanced?
    balance_sheet_items.any? && total("asset").positive? && total("asset") == total("liability") + total("equity")
  end

  private

  def protected_questions
    Question.where(id: [ question_id, question_id_in_database ])
  end
end
