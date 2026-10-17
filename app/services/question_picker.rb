class QuestionPicker
  class NotEnoughQuestions < StandardError; end

  def self.call(industry)
    scope = Question.available
    scope = scope.where(industry: industry) if industry
    ids = scope.pluck(:id).sample(5)
    raise NotEnoughQuestions, "この業種は5問の準備ができていません。別の業種を選んでください。" if ids.size < 5
    ids
  end
end
