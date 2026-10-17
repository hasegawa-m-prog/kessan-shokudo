require "rails_helper"
require Rails.root.join("lib/demo_learning_content")

RSpec.describe "Learning content publication", type: :model do
  before { DemoLearningContent.load! }

  def draft_copy(source = Question.first)
    draft = source.dup
    draft.assign_attributes(version: source.version + 1, published_at: nil, retired_at: nil)
    draft.save!
    source.choices.each { |choice| draft.choices.create!(choice.attributes.slice("position", "body", "is_correct")) }
    source.balance_sheets.each do |sheet|
      copy = draft.balance_sheets.create!(sheet.attributes.slice("position", "company_name", "business_description"))
      sheet.balance_sheet_items.each { |item| copy.balance_sheet_items.create!(item.attributes.slice("account_id", "amount")) }
    end
    source.retire!
    draft
  end

  it "provides 15 distinct development examples, each with a single answer and balanced diagrams" do
    expect(Question.available.count).to eq(15)
    Question.with_diagrams.each do |question|
      expect(question.choices.size).to eq(3)
      expect(question.choices.count(&:is_correct)).to eq(1)
      expect(question.balance_sheets.size).to eq(2)
      expect(question.balance_sheets).to all(be_balanced)
      expect(question.balance_sheets.flat_map { |sheet| sheet.balance_sheet_items.map { |item| item.account.name } }).not_to include("出資金")
    end
    expect { DemoLearningContent.load! }.not_to change(Question, :count)
  end

  it "refuses to load demonstration content in production" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
    expect { DemoLearningContent.load! }.to raise_error(/開発・テスト環境専用/)
  end

  it "requires exactly three choices and one correct answer at publication" do
    draft = draft_copy
    draft.choices.where(is_correct: true).first.update!(is_correct: false)
    expect { draft.publish! }.to raise_error(ActiveRecord::RecordInvalid, /正解は1件/)
    draft.reload
    draft.choices.first.update!(is_correct: true)
    draft.choices.last.destroy!
    expect { draft.publish! }.to raise_error(ActiveRecord::RecordInvalid, /選択肢/)
  end

  it "refuses multiple correct answers" do
    draft = draft_copy
    draft.choices.last.update!(is_correct: true)
    expect { draft.publish! }.to raise_error(ActiveRecord::RecordInvalid, /正解は1件/)
  end

  it "requires two balanced diagrams and the same company for a transaction" do
    draft = draft_copy(Question.find_by!(kind: "transaction"))
    sheet = draft.balance_sheets.last
    sheet.update!(company_name: "別の会社")
    expect { draft.publish! }.to raise_error(ActiveRecord::RecordInvalid, /同じ会社/)
    draft.reload
    sheet.update!(company_name: draft.balance_sheets.first.company_name)
    sheet.balance_sheet_items.first.update!(amount: 1)
    expect { draft.publish! }.to raise_error(ActiveRecord::RecordInvalid, /一致しません/)
  end

  it "rejects missing diagrams, future dates and invalid amounts" do
    industry = Industry.first
    draft = Question.create!(industry: industry, code: "empty", version: 1, kind: "transaction", title: "テスト", body: "本文", assumptions: "条件", explanation: "説明")
    expect { draft.publish! }.to raise_error(ActiveRecord::RecordInvalid, /BSは/)
    draft = draft_copy
    expect(draft.update(published_at: 1.day.from_now)).to be(false)
    expect(draft.balance_sheets.first.balance_sheet_items.first.update(amount: -1)).to be(false)
  end

  it "keeps published questions, choices, diagrams and accounts immutable" do
    question = Question.first
    expect(question.update(title: "changed")).to be(false)
    expect(question.destroy).to be(false)
    choice = question.choices.first
    expect(choice.update(is_correct: !choice.is_correct)).to be(false)
    expect(choice.destroy).to be(false)
    sheet = question.balance_sheets.first
    expect(sheet.update(company_name: "changed")).to be(false)
    item = sheet.balance_sheet_items.first
    expect(item.update(amount: 10)).to be(false)
    expect(item.destroy).to be(false)
    expect(item.account.update(name: "changed")).to be(false)
  end

  it "does not allow reparenting protected content or adding items after publication" do
    question = Question.first
    draft = draft_copy(question)
    expect(question.choices.first.update(question: draft)).to be(false)
    expect(question.balance_sheets.first.update(question: draft)).to be(false)
    extra = Account.create!(name: "その他", category: "asset")
    item = question.balance_sheets.first.balance_sheet_items.build(account: extra, amount: 0)
    expect(item.save).to be(false)
  end

  it "retires an old version without changing it and makes only the new version available" do
    old = Question.first
    draft = draft_copy(old)
    draft.update!(title: "改訂版")
    draft.publish!
    expect(Question.available.where(code: old.code).pluck(:id)).to eq([ draft.id ])
    expect(old.reload.title).not_to eq("改訂版")
    expect(old.update(retired_at: nil)).to be(false)
  end

  it "selects five unique available questions from the specified industry" do
    Industry.all.each do |industry|
      ids = QuestionPicker.call(industry)
      expect(ids.uniq.size).to eq(5)
      expect(Question.where(id: ids).pluck(:industry_id).uniq).to eq([ industry.id ])
    end
    expect(QuestionPicker.call(nil).uniq.size).to eq(5)
    Question.first.retire!
    expect { QuestionPicker.call(Question.first.industry) }.to raise_error(QuestionPicker::NotEnoughQuestions)
  end
end
