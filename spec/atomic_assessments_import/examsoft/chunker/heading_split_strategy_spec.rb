# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Chunker::HeadingSplitStrategy do
  describe "#split" do
    it "splits on heading tags" do
      html = <<~HTML
        <h2>Question 1</h2>
        <p>What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
        <h2>Question 2</h2>
        <p>What is H2O?</p>
        <p>a) Water</p>
        <p>b) Fire</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "returns empty array when no headings found" do
      html = "<p>Just some regular text</p><p>More text</p>"
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks).to eq([])
    end

    it "separates header content before first heading" do
      html = <<~HTML
        <p>Exam: Midterm 2024</p>
        <p>Total Questions: 30</p>
        <h2>Question 1</h2>
        <p>What is the capital of France?</p>
        <p>a) Paris</p>
        <h2>Question 2</h2>
        <p>What is H2O?</p>
        <p>a) Water</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(2)
      expect(strategy.header_nodes).not_to be_empty
    end
  end
end
