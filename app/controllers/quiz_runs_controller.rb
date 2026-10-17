class QuizRunsController < ApplicationController
  before_action :require_login

  def show
    @run = current_user.quiz_runs.with_answers.includes(:industry, quiz_run_questions: [ :question, { answer: :choice } ]).find(params[:id])
    @reviewable_answer_ids = current_user.answers.reviewable.where(quiz_run_questions: { quiz_run_id: @run.id }).pluck(:id)
  end
end
