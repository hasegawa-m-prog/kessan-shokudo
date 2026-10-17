# ゲストは暗号化Cookie、会員はDBに進行を保存します。正誤は常にDBの選択肢で判定します。
class QuizAttempt
  class InvalidAnswer < StandardError; end
  class Expired < StandardError; end
  class StaleForm < StandardError; end
  attr_reader :token, :questions, :selected_ids, :industry_name

  def self.start(session:, user:, industry:)
    ids = QuestionPicker.call(industry)
    state = { "token" => SecureRandom.hex(16), "started_at" => Time.current.to_i }
    if user
      run = QuizRun.transaction do
        run = user.quiz_runs.create!(industry: industry, kind: "quiz", started_at: Time.current)
        ids.each_with_index { |id, index| run.quiz_run_questions.create!(question_id: id, position: index + 1) }
        run
      end
      state["run_id"] = run.id
    else
      state.merge!("ids" => ids, "answers" => [], "industry" => industry&.name || "おまかせ")
    end
    session[:quiz] = state
    new(session: session, user: user)
  end

  def initialize(session:, user:)
    @session, @user = session, user
    @state = session[:quiz]
    raise Expired unless @state.is_a?(Hash) && @state["started_at"].to_i > 2.hours.ago.to_i
    @token = @state.fetch("token")
    if @state["run_id"]
      raise Expired unless user
      @run = user.quiz_runs.find_by(id: @state["run_id"])
      raise Expired unless @run
      reload_member
      @industry_name = @run.industry&.name || "おまかせ"
    else
      raise Expired if user # ゲストの記録を会員へ引き継がない
      @selected_ids = @state.fetch("answers")
      load_questions(@state.fetch("ids"))
      @industry_name = @state.fetch("industry")
    end
  rescue KeyError
    raise Expired
  end

  def completed?
    selected_ids.size == questions.size
  end

  def answer!(position:, choice_id:, token:)
    raise StaleForm unless token == @token
    if @run
      @run.with_lock do
        reload_member
        choice = validate_answer(position, choice_id)
        if choice
          @run.quiz_run_questions.find_by!(position: position).create_answer!(choice: choice, answered_at: Time.current)
          @run.update!(completed_at: Time.current) if position == questions.size
          reload_member
        end
      end
    else
      choice = validate_answer(position, choice_id)
      if choice
        @selected_ids = selected_ids + [ choice.id ]
        @session[:quiz] = @state.merge("answers" => selected_ids)
      end
    end
  end

  def selected_choice(index)
    questions[index].choices.find { |choice| choice.id == selected_ids[index] }
  end

  def correct_count
    selected_ids.each_index.count { |index| selected_choice(index)&.is_correct }
  end

  private

  def load_questions(ids)
    records = Question.with_diagrams.where(id: ids).index_by(&:id)
    @questions = ids.map { |id| records.fetch(id) }
    raise Expired unless questions.size == 5
  end

  def reload_member
    entries = @run.quiz_run_questions.includes(:answer).to_a
    load_questions(entries.map(&:question_id))
    @selected_ids = entries.filter_map { |entry| entry.answer&.choice_id }
  end

  def validate_answer(position, choice_id)
    raise InvalidAnswer, "表示されている問題に回答してください。" unless position.between?(1, questions.size)
    return nil if position <= selected_ids.size # 同じPOSTの再送は最初の回答を維持
    raise InvalidAnswer, "順番に回答してください。" unless position == selected_ids.size + 1
    choice = questions[position - 1].choices.find { |candidate| candidate.id.to_s == choice_id.to_s }
    raise InvalidAnswer, "この問題の選択肢を1つ選んでください。" unless choice
    choice
  end
end
