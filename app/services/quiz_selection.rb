# ログイン・登録画面を経由しても、許可された業種だけを引き継ぎます。
# 遷移先URLやゲストの回答は受け取りません。
class QuizSelection
  attr_reader :industry

  def self.find(value)
    return new(nil) if value == "random"
    return unless value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)

    industry = Industry.find_by(id: value)
    new(industry) if industry
  end

  def initialize(industry)
    @industry = industry
  end

  def key
    industry&.id&.to_s || "random"
  end

  def name
    industry&.name || "おまかせ"
  end
end
