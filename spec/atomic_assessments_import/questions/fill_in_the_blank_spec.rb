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
      expect(result[:data][:template]).to eq("The capital of France is {{response}}.")
    end

    it "puts scoring_type at top level of validation, not inside valid_response" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:validation][:scoring_type]).to eq("partialMatchV2")
      expect(result[:data][:validation][:valid_response].keys).not_to include(:scoring_type)
    end

    it "includes each answer as a flat array of strings in valid_response value" do
      row["correct answer"] = "Paris; Lyon; Marseille"
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:validation][:valid_response][:value]).to eq(["Paris", "Lyon", "Marseille"])
      expect(result[:data][:validation][:valid_response][:score]).to eq(1)
    end

    it "replaces __n__ blank markers in the stimulus with {{response}}" do
      row["question text"] = "The color __1__ consists of primary, secondary, and __2__ colors."
      row["correct answer"] = "wheel; tertiary"
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:template]).to eq("The color {{response}} consists of primary, secondary, and {{response}} colors.")
    end

    it "appends {{response}} to template when question text has no placeholder" do
      row["question text"] = "Name the active compound."
      row["correct answer"] = "Salicin"
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:template]).to eq("Name the active compound. {{response}}")
    end

    it "appends one {{response}} per answer when question text has no placeholder and multiple answers" do
      row["question text"] = "Fill in both capitals."
      row["correct answer"] = "Paris; Berlin"
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:template]).to eq("Fill in both capitals. {{response}} {{response}}")
    end

    it "leaves template unchanged when it already contains {{response}}" do
      row["question text"] = "The capital of France is {{response}}."
      row["correct answer"] = "Paris"
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:template]).to eq("The capital of France is {{response}}.")
    end
  end
end
