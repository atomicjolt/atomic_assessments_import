# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::Essay do
  let(:row) do
    {
      "question text" => "Discuss the causes of World War I.",
      "question type" => "essay",
      "general feedback" => "A good answer covers alliances, imperialism, and nationalism.",
      "sample answer" => "World War I was caused by...",
      "points" => "10",
    }
  end

  describe "#question_type" do
    it "returns longanswer" do
      question = described_class.new(row)
      expect(question.question_type).to eq("longanswer")
    end
  end

  describe "#to_learnosity" do
    it "returns correct structure" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:type]).to eq("longanswer")
      expect(result[:widget_type]).to eq("response")
      expect(result[:data][:stimulus]).to eq("Discuss the causes of World War I.")
    end

    it "includes max_length when word limit specified" do
      row["word_limit"] = "500"
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:max_length]).to eq(500)
    end

    it "sets metadata" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:metadata][:sample_answer]).to eq("World War I was caused by...")
      expect(result[:data][:metadata][:general_feedback]).to eq("A good answer covers alliances, imperialism, and nationalism.")
    end
  end
end
