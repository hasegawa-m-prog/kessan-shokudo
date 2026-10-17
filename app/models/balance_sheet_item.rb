class BalanceSheetItem < ApplicationRecord
  include PublishedContent
  belongs_to :balance_sheet
  belongs_to :account
  validates :account_id, uniqueness: { scope: :balance_sheet_id }
  validates :amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def protected_questions
    Question.where(id: BalanceSheet.where(id: [ balance_sheet_id, balance_sheet_id_in_database ]).select(:question_id))
  end
end
