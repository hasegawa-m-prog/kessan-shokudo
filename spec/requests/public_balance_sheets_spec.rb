require "rails_helper"
require Rails.root.join("lib/public_learning_content")

RSpec.describe "Public BS rendering", type: :request do
  before { PublicLearningContent.load! }

  def verify_diagrams(question, sheets)
    html = Nokogiri::HTML(response.body)
    cards = html.css(".balance-sheet")
    expect(response.body).to include("小数第1位に丸めるため")
    expect(cards.size).to eq(sheets.size)
    maximum = sheets.map { |sheet| sheet.total("asset") }.max
    cards.zip(sheets).each do |card, sheet|
      expect(card.at_css("h3").text).to include(sheet.company_name)
      rects = card.css("rect")
      expect(rects.size).to eq(5)
      sheet.balance_sheet_items.each do |item|
        formatted = "#{ActiveSupport::NumberHelper.number_to_delimited(item.amount)}円"
        rect = rects.find { |node| node.at_css("title").text == "#{item.account.name}：#{formatted}" }
        expect(rect).not_to be_nil
        expect(rect["class"]).to include(item.account.category)
        expect(rect["x"].to_f).to eq(item.account.category == "asset" ? 10 : 170)
        expect(rect["height"].to_f).to be_within(0.00001).of(item.amount.fdiv(maximum) * 180)
        expect(rect["y"].to_f).to be >= 30 - 0.00001
        expect(rect["y"].to_f + rect["height"].to_f).to be <= 210 + 0.00001
        amount_row = card.css(".amount-list div").find { |row| row.at_css("dt").text.strip.end_with?(item.account.name) }
        expect(amount_row.text).to include(formatted, format("%.1f%%", item.amount.fdiv(sheet.total("asset")) * 100))
      end
      totals = card.css('svg > text[y="234"]').map(&:text)
      expect(totals.uniq.size).to eq(1)
      expect(totals.first).to eq("合計 #{ActiveSupport::NumberHelper.number_to_delimited(sheet.total('asset'))}円")
    end
  end

  it "renders every public question with correct categories, amounts, percentages, common scales and answers" do
    Industry.order(:id).each do |industry|
      questions = Question.with_diagrams.where(industry: industry).order(:code).to_a
      allow(QuestionPicker).to receive(:call).with(industry).and_return(questions.map(&:id))
      post quiz_path, params: { industry_id: industry.id }
      questions.each_with_index do |question, index|
        get quiz_path(position: index + 1)
        expect(response).to have_http_status(:ok)
        sheets = question.balance_sheets.to_a
        verify_diagrams(question, question.kind == "transaction" ? sheets.first(1) : sheets)
        expect(response.body).not_to include(question.explanation)
        html = Nokogiri::HTML(response.body)
        choices = html.css('input[name="choice_id"]')
        expect(choices.size).to eq(3)
        post answer_quiz_path, params: { position: index + 1, choice_id: question.correct_choice.id,
          attempt_token: html.at_css('input[name="attempt_token"]')["value"] }
        follow_redirect!
        expect(response.body).to include("○ 正解です", ERB::Util.html_escape(question.explanation))
        verify_diagrams(question, sheets)
        if question.kind == "transaction"
          before = sheets.first.balance_sheet_items.index_by(&:account_id)
          sheets.last.balance_sheet_items.each do |item|
            change = item.amount - before.fetch(item.account_id).amount
            next if change.zero?
            expect(response.body).to include("#{item.account.name}：#{ActiveSupport::NumberHelper.number_to_delimited(change.abs)}円#{change.positive? ? '増加' : '減少'}")
          end
        end
      end
      get result_quiz_path
      expect(response.body).to include("<strong>5問</strong>")
    end
  end
end
