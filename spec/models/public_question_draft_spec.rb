require "rails_helper"

RSpec.describe "Public question draft arithmetic" do
  let(:document) { Rails.root.join("docs/public-question-review.md").read }
  let(:sheets) do
    document.lines.filter_map do |line|
      cells = line.split("|").map(&:strip)
      next unless cells[1]&.match?(/\A[RMS][1-5]-/)
      [ cells[1], cells[2..6].map { |value| Integer(value, 10) } ]
    end.to_h
  end

  it "has 15 questions and 30 balanced, nonnegative BS examples" do
    expect(document.scan(/^### [RMS][1-5] /).size).to eq(15)
    expect(sheets.size).to eq(30)
    sheets.each do |name, amounts|
      expect(amounts).to all(be >= 0)
      expect(amounts.first(3).sum).to eq(amounts.last(2).sum), name
    end
  end

  it "matches the five company comparisons and their stated ratios" do
    { "R1" => [ 1, [ 20, 0 ] ], "R5" => [ 2, [ 30, 30 ] ], "M1" => [ 2, [ 60, 40 ] ],
      "M5" => [ 3, [ 40, 30 ] ], "S1" => [ 1, [ 0, 40 ] ] }.each do |code, (account, expected)|
      actual = sheets.select { |name, _| name.start_with?("#{code}-") }.values.map { |amounts| amounts[account].fdiv(amounts.first(3).sum) * 100 }
      expect(actual).to eq(expected), code
    end
  end

  it "matches each transaction's explicitly stated changes without any hidden changes" do
    { "R2" => [ -100, 100, 0, 0, 0 ], "R3" => [ 200, 0, 0, 200, 0 ], "R4" => [ -100, 0, 0, -100, 0 ],
      "M2" => [ -200, 0, 200, 0, 0 ], "M3" => [ -100, 100, 0, 0, 0 ], "M4" => [ 300, 0, 0, 300, 0 ],
      "S2" => [ -100, 0, 100, 0, 0 ], "S3" => [ 100, 0, 0, 100, 0 ], "S4" => [ -200, 0, 0, -200, 0 ],
      "S5" => [ 200, 0, 0, 0, 200 ] }.each do |code, expected|
      before = sheets.fetch("#{code}-前")
      after = sheets.fetch("#{code}-後")
      expect(after.zip(before).map { |new_amount, old_amount| new_amount - old_amount }).to eq(expected), code
    end
    expect(sheets.fetch("M4-後")[3]).to eq(700)
    expect(sheets.fetch("S4-後").first(3).sum).to eq(800)
    expect(sheets.fetch("S5-後")[4]).to eq(900)
  end
end
