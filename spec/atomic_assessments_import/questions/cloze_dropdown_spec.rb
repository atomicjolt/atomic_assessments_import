# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::ClozeDropdown do
  let(:row) do
    {
      "question text" => "The _____ Ocean is the world's largest body of water.",
      "question type" => "fill_in_the_blank",
      "option a" => "Choice of: Pacific | Indian | Southern | Atlantic | Arctic | 1",
      "points" => "1",
    }
  end

  describe "#question_type" do
    it "returns clozedropdown" do
      question = described_class.new(row)
      expect(question.question_type).to eq("clozedropdown")
    end
  end

  describe "#to_learnosity" do
    it "puts scoring_type at top level of validation, not inside valid_response" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:validation][:scoring_type]).to eq("partialMatchV2")
      expect(result[:data][:validation][:valid_response].keys).not_to include(:scoring_type)
    end

    it "puts question text with {{response}} in template and leaves stimulus empty" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:template]).to include("{{response}}")
      expect(result[:data][:stimulus]).to eq("")
    end

    it "replaces _____ blank marker with {{response}} in template" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:template]).to eq("The {{response}} Ocean is the world's largest body of water.")
    end

    it "builds possible_responses as array of arrays from Choice of: options" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:possible_responses]).to eq([
        ["Pacific", "Indian", "Southern", "Atlantic", "Arctic"],
      ])
    end

    it "sets valid_response value to the correct answer string" do
      question = described_class.new(row)
      result = question.to_learnosity
      # "| 1" means first item (1-indexed) = "Pacific"
      expect(result[:data][:validation][:valid_response][:value]).to eq(["Pacific"])
    end

    context "with multiple blanks" do
      let(:row) do
        {
          "question text" => "The __1__ and __2__ are both planets.",
          "question type" => "fill_in_the_blank",
          "option a" => "Choice of: Mercury | Venus | Earth | 1",
          "option b" => "Choice of: Mars | Jupiter | Saturn | 2",
          "points" => "2",
        }
      end

      it "builds possible_responses for each blank" do
        question = described_class.new(row)
        result = question.to_learnosity
        expect(result[:data][:possible_responses]).to eq([
          ["Mercury", "Venus", "Earth"],
          ["Mars", "Jupiter", "Saturn"],
        ])
      end

      it "sets valid_response value for each blank in order" do
        question = described_class.new(row)
        result = question.to_learnosity
        # option a: index 1 = "Mercury"; option b: index 2 = "Jupiter"
        expect(result[:data][:validation][:valid_response][:value]).to eq(["Mercury", "Jupiter"])
      end

      it "replaces __n__ markers with {{response}} in template" do
        question = described_class.new(row)
        result = question.to_learnosity
        expect(result[:data][:template]).to eq("The {{response}} and {{response}} are both planets.")
      end
    end
  end
end
