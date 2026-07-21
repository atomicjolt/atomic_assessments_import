# frozen_string_literal: true

require "spec_helper"

RSpec.describe AtomicAssessmentsImport::Questions::Classification do
  let(:row) do
    {
      "question text" => "<p>Drag the correct answers to the right.</p>",
      "possible responses" => ["Use small gauge", "Shave the site", "Use warm compress"],
      "correct answer" => "a;c",
      "points" => "4",
    }
  end

  it "builds a classification with one target container" do
    data = described_class.new(row).question_data
    expect(data[:type]).to eq("classification")
    expect(data[:possible_responses]).to eq(["Use small gauge", "Shave the site", "Use warm compress"])
    expect(data[:ui_style]).to eq(column_titles: ["Correct Answers"], row_titles: [], column_count: 1, row_count: 1)
    expect(data[:max_response_per_cell]).to eq(3)
    expect(data[:validation]).to eq(
      scoring_type: "partialMatchV2",
      valid_response: { score: 4.0, value: [[0, 2]] },
      penalty: 1,
      rounding: "none",
    )
  end

  it "raises without a correct answer" do
    expect { described_class.new(row.merge("correct answer" => nil)).question_data }
      .to raise_error("Missing correct answer")
  end
end
