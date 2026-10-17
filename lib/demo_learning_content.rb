# 画面・保存処理の動作確認専用。公開教材として扱わない。
class DemoLearningContent
  ACCOUNTS = { "現金" => "asset", "在庫" => "asset", "設備" => "asset", "借入金" => "liability", "出資金" => "equity" }.freeze
  BASE = [ 500, 200, 300, 400, 600 ].freeze

  def self.load!
    raise "動作確認用データは開発・テスト環境専用です" unless Rails.env.development? || Rails.env.test?
    ApplicationRecord.transaction do
      accounts = ACCOUNTS.map { |name, category| Account.find_or_create_by!(name: name, category: category) }
      Industry::NAMES.each_with_index do |name, industry_index|
        industry = Industry.find_or_create_by!(name: name)
        examples.each_with_index do |example, index|
          code = "demo-#{industry_index + 1}-#{index + 1}"
          next if Question.exists?(code: code, version: 1)
          question = Question.create!(industry: industry, code: code, version: 1, kind: example[:kind],
            title: "【動作確認用】#{example[:title]}", body: example[:body],
            assumptions: "架空の単純化した事例です。税金・手数料・減価償却は考慮しません。業種の一般的な構成を示すものではありません。公開教材としての確認は未完了です。",
            explanation: example[:explanation])
          example[:choices].each_with_index do |body, position|
            question.choices.create!(position: position + 1, body: body, is_correct: position == index % 3)
          end
          [ example[:before] || BASE, example[:after] ].each_with_index do |amounts, sheet_index|
            company = example[:kind] == "transaction" || sheet_index.zero? ? "架空A社" : "架空B社"
            sheet = question.balance_sheets.create!(position: sheet_index + 1, company_name: company,
              business_description: "#{name}の架空事例。仕事の具体的な条件は問題文を参照してください。")
            accounts.zip(amounts).each { |account, amount| sheet.balance_sheet_items.create!(account: account, amount: amount * 10_000) }
          end
          question.publish!
        end
      end
    end
  end

  def self.examples
    [
      { kind: "company_comparison", title: "在庫の割合を比べる", after: [ 700, 0, 300, 400, 600 ],
        body: "A社は商品を保有し、B社は在庫を保有しない条件の例です。資産合計に対する在庫の割合が高いのはどちらですか？",
        choices: [ "A社", "B社", "同じ割合" ], explanation: "A社の在庫は200万円／資産1,000万円で20%、B社は0%です。在庫の多さは会社の優劣を示しません。業種名だけでは判断できない点に注意します。" },
      { kind: "transaction", title: "現金で設備を購入する", after: [ 400, 200, 400, 400, 600 ],
        body: "設備100万円を現金で購入しました。購入直後の資産合計はどうなりますか？",
        choices: [ "100万円増える", "変わらない", "100万円減る" ], explanation: "現金が100万円減り、設備が100万円増えます。資産の内訳が変わるだけで、資産合計は1,000万円のままです。現金の減少だけを見ないようにします。" },
      { kind: "transaction", title: "現金を借り入れる", after: [ 600, 200, 300, 500, 600 ],
        body: "銀行から100万円を借り入れ、現金を受け取りました。資産と負債はどうなりますか？",
        choices: [ "資産だけ100万円増える", "資産と純資産が100万円ずつ増える", "資産と負債が100万円ずつ増える" ], explanation: "現金と借入金がそれぞれ100万円増えます。返す必要のあるお金なので、純資産は増えません。" },
      { kind: "transaction", title: "借入金を返済する", after: [ 400, 200, 300, 300, 600 ],
        body: "借入金の元本100万円を現金で返済しました。資産と負債はどうなりますか？",
        choices: [ "資産と負債が100万円ずつ減る", "資産だけ100万円減る", "資産と純資産が100万円ずつ減る" ], explanation: "現金と借入金がそれぞれ100万円減ります。ここでは利息を含まない元本のみの返済なので、純資産は変わりません。" },
      { kind: "company_comparison", title: "金額と割合を区別する", after: [ 1000, 400, 600, 800, 1200 ],
        body: "A社とB社は資産合計が異なります。資産合計に対する設備の割合はどちらが高いですか？",
        choices: [ "B社", "同じ割合", "A社" ], explanation: "A社は300万円／1,000万円、B社は600万円／2,000万円で、どちらも30%です。設備の金額が大きくても、割合が高いとは限りません。" }
    ]
  end
end
