# frozen_string_literal: true

require "spec_helper"

RSpec.describe AtomicAssessmentsImport::Questions::Bowtie do
  let(:row) do
    {
      "question text" => "<p>Drag the answers.</p>",
      "response groups" => [
        { title: "Action to Take (choose 2)", responses: ["a1", "a2", "a3"] },
        { title: "Potential Condition (choose 1)", responses: ["c1", "c2"] },
        { title: "Parameter to Monitor (choose 2)", responses: ["p1", "p2", "p3"] },
      ],
    }
  end

  it "builds a native Learnosity bowtie" do
    data = described_class.new(row).question_data
    expect(data[:type]).to eq("bowtie")
    expect(data[:ui_style]).to eq(column_titles: ["Action to Take (choose 2)", "Potential Condition (choose 1)", "Parameter to Monitor (choose 2)"], show_drag_handle: false)
    expect(data[:group_possible_responses]).to be(true)
    expect(data[:possible_response_groups]).to eq(row["response groups"])
    expect(data).not_to have_key(:validation)
  end

  it "is constructable through Question.load" do
    q = AtomicAssessmentsImport::Questions::Question.load(row.merge("question type" => "bowtie"))
    expect(q).to be_a(described_class)
  end
end
