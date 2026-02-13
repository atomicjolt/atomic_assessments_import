# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Chunker::NumberedQuestionStrategy do
  describe "#split" do
    it "splits on paragraphs starting with number-paren pattern" do
      html = <<~HTML
        <p>1) What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
        <p>2) What is H2O?</p>
        <p>a) Water</p>
        <p>b) Fire</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "splits on paragraphs starting with number-dot pattern" do
      html = <<~HTML
        <p>1. What is the capital of France?</p>
        <p>a) Paris</p>
        <p>2. What is H2O?</p>
        <p>a) Water</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "returns empty array when no numbered questions found" do
      html = "<p>Just some regular text</p><p>More text</p>"
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks).to eq([])
    end

    it "separates header content before first question" do
      html = <<~HTML
        <p>Exam: Midterm</p>
        <p>Total: 30 questions</p>
        <p>1) First question?</p>
        <p>a) Answer</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(1)
      expect(strategy.header_nodes.length).to eq(2)
    end

    it "does not split on lettered options like a) b) c)" do
      html = <<~HTML
        <p>1) What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
        <p>c) Berlin</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks.length).to eq(1)
    end
  end
end
