# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::Ordering do
  let(:row) do
    {
      "question text" => "Arrange these events in chronological order.",
      "question type" => "ordering",
      "option a" => "World War I",
      "option b" => "World War II",
      "option c" => "Cold War",
      "correct answer" => "a; b; c",
      "points" => "3",
    }
  end

  describe "#question_type" do
    it "returns orderlist" do
      question = described_class.new(row)
      expect(question.question_type).to eq("orderlist")
    end
  end

  describe "#to_learnosity" do
    it "has correct list items" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:list]).to eq(["World War I", "World War II", "Cold War"])
    end

    it "includes validation with correct order indices as integers" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:validation][:valid_response][:value]).to eq([0, 1, 2])
      expect(result[:data][:validation][:valid_response][:score]).to eq(3)
    end

    it "puts scoring_type at top level of validation" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:validation][:scoring_type]).to eq("partialMatchV2")
      expect(result[:data][:validation][:valid_response].keys).not_to include(:scoring_type)
    end

    context "with ExamSoft --- n order markers" do
      let(:row) do
        {
          "question text" => "Drag and rearrange the following colors in alphabetical order.",
          "question type" => "ordering",
          "option a" => "Yellow --- 4",
          "option b" => "Orange --- 2",
          "option c" => "Green --- 1",
          "option d" => "Red --- 3",
          "points" => "1",
        }
      end

      it "strips --- n markers from list items" do
        question = described_class.new(row)
        result = question.to_learnosity
        expect(result[:data][:list]).to eq(["Yellow", "Orange", "Green", "Red"])
      end

      it "derives correct order from --- n numbers as integers" do
        question = described_class.new(row)
        result = question.to_learnosity
        # Green=1, Orange=2, Red=3, Yellow=4 → indices in list: [2, 1, 3, 0]
        expect(result[:data][:validation][:valid_response][:value]).to eq([2, 1, 3, 0])
      end
    end
  end
end
