require "rails_helper"
require Rails.root.join("lib/public_learning_content")
require Rails.root.join("lib/demo_learning_content")

RSpec.describe PublicLearningContent, type: :model do
  let(:data) { JSON.parse(described_class::PATH.read) }

  it "matches all reviewed question text, choices, answers and 30 BS values in yen" do
    document = Rails.root.join("docs/public-question-review.md").read
    sections = document.split(/^### (?=[RMS][1-5] )/).drop(1)
    expect(sections.size).to eq(15)
    sections.zip(data.fetch("questions")).each do |section, question|
      heading, rest = section.split("\n", 2)
      code, title = heading.split(" ", 2)
      expect(question.fetch("code")).to eq("bs-#{code.downcase}")
      expect(question.fetch("title")).to eq(title)
      expect(question.fetch("body")).to eq(rest.strip.split("\n\n").first)
      choices = section.match(/^選択肢：①(.+)　②(.+)　③(.+)$/).captures
      correct, explanation = section.match(/^正解：([①②③])。(.+)$/).captures
      expect(question.fetch("choices").map { |choice| choice.fetch("body") }).to eq(choices)
      expect(question.fetch("choices").map { |choice| choice.fetch("is_correct") }).to eq((0..2).map { |i| i == "①②③".index(correct) })
      expect(question.fetch("explanation")).to eq(explanation)
      amounts = section.lines.filter_map do |line|
        cells = line.split("|").map(&:strip)
        cells[2..6].map { |value| Integer(value, 10) * 10_000 } if cells[1]&.start_with?("#{code}-")
      end
      expect(question.fetch("sheets").map { |sheet| sheet.fetch("amounts") }).to eq(amounts)
    end
  end

  it "publishes exactly five questions per industry with balanced BS and is idempotent" do
    described_class.load!
    expect(Question.available.count).to eq(15)
    Industry.all.each do |industry|
      expect(Question.available.where(industry: industry).count).to eq(5)
    end
    Question.with_diagrams.each do |question|
      expect(question.choices.count(&:is_correct)).to eq(1)
      expect(question.balance_sheets).to all(be_balanced)
      expect(question.assumptions).to include("架空", "税金", "利益剰余金", "元本のみ")
    end
    expect { described_class.load! }.not_to change { [ Question.count, Choice.count, BalanceSheetItem.count ] }
  end

  it "retires demonstration questions while preserving old answers and an in-progress run" do
    DemoLearningContent.load!
    session = {}
    user = create(:user)
    attempt = QuizAttempt.start(session: session, user: user, industry: Industry.first)
    old = attempt.questions.first
    attempt.answer!(position: 1, choice_id: old.correct_choice.id, token: attempt.token)
    answer = user.answers.sole
    original = answer.attributes
    described_class.load!
    expect(Question.available.where(code: described_class::DEMO_CODES)).to be_empty
    expect(Question.count).to eq(30)
    expect(answer.reload.attributes).to eq(original)
    expect(answer.choice.body).to eq(old.correct_choice.body)
    resumed = QuizAttempt.new(session: session, user: user)
    expect(resumed.questions.map(&:id)).to eq(attempt.questions.map(&:id))
    expect(resumed.selected_ids).to eq([ answer.choice_id ])
  end

  it "does not silently overwrite a published version or reactivate retired content" do
    described_class.load!
    data.fetch("questions").first["title"] = "changed"
    expect { described_class.load!(data: data) }.to raise_error(described_class::ContentMismatch, /上書きせず/)
    question = Question.find_by!(code: "bs-r1")
    question.retire!
    described_class.load!
    expect(question.reload.retired_at).to be_present
  end

  it "rolls back the whole import when any question has an unbalanced BS" do
    DemoLearningContent.load!
    data.fetch("questions").last.fetch("sheets").last.fetch("amounts")[0] += 1
    expect { described_class.load!(data: data) }.to raise_error(ActiveRecord::RecordInvalid, /一致しません/)
    expect(Question.available.count).to eq(15)
    expect(Question.where(code: described_class::CODES)).to be_empty
  end

  it "rejects wrong categories, missing questions and invalid amounts before writing" do
    malformed = data.deep_dup
    malformed.fetch("accounts").last["category"] = "asset"
    expect { described_class.load!(data: malformed) }.to raise_error(described_class::ContentMismatch)
    malformed = data.deep_dup
    malformed.fetch("questions").pop
    expect { described_class.load!(data: malformed) }.to raise_error(described_class::ContentMismatch)
    malformed = data.deep_dup
    malformed.fetch("questions").first.fetch("sheets").first.fetch("amounts")[0] = -1
    expect { described_class.load!(data: malformed) }.to raise_error(described_class::ContentMismatch)
    expect(Question.count).to eq(0)
  end
end
