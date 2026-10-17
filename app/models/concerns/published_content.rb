# 公開済み問題の子データは、追加・移動・変更・削除を禁止します。
module PublishedContent
  extend ActiveSupport::Concern
  included do
    validate :published_content_is_immutable
    before_destroy :prevent_published_content_destruction
  end

  private

  def published_content_is_immutable
    errors.add(:base, "公開済みのデータは変更できません") if protected_questions.any? { |q| q&.published_at.present? }
  end

  def prevent_published_content_destruction
    return unless protected_questions.any? { |q| q&.published_at.present? }
    errors.add(:base, "公開済みのデータは削除できません")
    throw :abort
  end
end
