# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::QuestionStemDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "extracts question text before options" do
      nodes = nodes_from(<<~HTML)
        <p>1) What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result).to eq("What is the capital of France?")
    end

    it "extracts question text with tilde-separated explanation removed" do
      nodes = nodes_from(<<~HTML)
        <p>Folder: Geo Title: Q1 Category: Test 1) What is the capital? ~ Paris is the capital of France.</p>
        <p>*a) Paris</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result).to eq("What is the capital?")
    end

    it "extracts question text without numbered prefix" do
      nodes = nodes_from(<<~HTML)
        <p>What is the capital of France?</p>
        <p>a) Paris</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result).to eq("What is the capital of France?")
    end

    it "strips metadata prefix up to question number, not a number embedded in parentheses like (Q-62)" do
      nodes = nodes_from(<<~HTML)
        <p>Type: MA Folder: Geography Title: Last Question (Q-62) Category: Difficulty/Very Hard 62) What is the population of Denver, CO as of 2021?</p>
        <p>*a) 711,000–713,000</p>
        <p>b) 713,000–715,000</p>
        <p>c) 715,000–717,000</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result).to eq("What is the population of Denver, CO as of 2021?")
    end

    it "returns nil when no question text found" do
      nodes = nodes_from("<p>a) Paris</p><p>b) London</p>")
      result = described_class.new(nodes).detect
      expect(result).to be_nil
    end
  end
end
