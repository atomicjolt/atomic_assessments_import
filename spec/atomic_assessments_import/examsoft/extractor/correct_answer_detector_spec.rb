# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::CorrectAnswerDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "detects correct answers from asterisk-marked options" do
      options = [
        { text: "Paris", letter: "a", correct: true },
        { text: "London", letter: "b", correct: false },
      ]
      result = described_class.new(nodes_from(""), options).detect
      expect(result).to eq(["a"])
    end

    it "detects multiple correct answers" do
      options = [
        { text: "Little Rock", letter: "a", correct: true },
        { text: "Denver", letter: "b", correct: true },
        { text: "Detroit", letter: "c", correct: false },
      ]
      result = described_class.new(nodes_from(""), options).detect
      expect(result).to eq(["a", "b"])
    end

    it "detects correct answer from Answer: label in chunk" do
      nodes = nodes_from("<p>Answer: A</p>")
      options = [
        { text: "Paris", letter: "a", correct: false },
        { text: "London", letter: "b", correct: false },
      ]
      result = described_class.new(nodes, options).detect
      expect(result).to eq(["a"])
    end

    it "returns empty array when no correct answer found" do
      options = [
        { text: "Paris", letter: "a", correct: false },
        { text: "London", letter: "b", correct: false },
      ]
      result = described_class.new(nodes_from(""), options).detect
      expect(result).to eq([])
    end
  end
end
