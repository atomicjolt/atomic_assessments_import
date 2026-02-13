# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::Matching do
  let(:row) do
    {
      "question text" => "Match the countries to their capitals.",
      "question type" => "matching",
      "option a" => "France",
      "option b" => "Germany",
      "option c" => "Spain",
      "match a" => "Paris",
      "match b" => "Berlin",
      "match c" => "Madrid",
      "points" => "3",
    }
  end

  describe "#question_type" do
    it "returns association" do
      question = described_class.new(row)
      expect(question.question_type).to eq("association")
    end
  end

  describe "#to_learnosity" do
    it "returns correct structure" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:type]).to eq("association")
      expect(result[:widget_type]).to eq("response")
      expect(result[:data][:stimulus]).to eq("Match the countries to their capitals.")
    end

    it "has correct stimulus_list and possible_responses lengths" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:stimulus_list]).to eq(["France", "Germany", "Spain"])
      expect(result[:data][:possible_responses]).to eq(["Paris", "Berlin", "Madrid"])
    end

    it "includes validation with correct match values" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:validation][:valid_response][:value]).to eq(["Paris", "Berlin", "Madrid"])
      expect(result[:data][:validation][:valid_response][:score]).to eq(3)
    end
  end
end
