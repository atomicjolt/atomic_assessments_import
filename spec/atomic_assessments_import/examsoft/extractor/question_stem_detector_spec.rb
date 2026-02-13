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

    it "returns nil when no question text found" do
      nodes = nodes_from("<p>a) Paris</p><p>b) London</p>")
      result = described_class.new(nodes).detect
      expect(result).to be_nil
    end
  end
end
