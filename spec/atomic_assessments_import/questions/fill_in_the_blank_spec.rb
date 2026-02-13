# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::FillInTheBlank do
  let(:row) do
    {
      "question text" => "The capital of France is {{response}}.",
      "question type" => "fill_in_the_blank",
      "correct answer" => "Paris",
      "points" => "1",
    }
  end

  describe "#question_type" do
    it "returns clozetext" do
      question = described_class.new(row)
      expect(question.question_type).to eq("clozetext")
    end
  end

  describe "#to_learnosity" do
    it "returns correct structure" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:type]).to eq("clozetext")
      expect(result[:widget_type]).to eq("response")
      expect(result[:data][:stimulus]).to eq("The capital of France is {{response}}.")
    end

    it "includes validation with correct answers array" do
      row["correct answer"] = "Paris; Lyon; Marseille"
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:validation][:valid_response][:value]).to eq(["Paris", "Lyon", "Marseille"])
      expect(result[:data][:validation][:valid_response][:score]).to eq(1)
    end
  end
end
