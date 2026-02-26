# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Chunker::HorizontalRuleSplitStrategy do
  describe "#split" do
    it "splits on hr tags" do
      html = <<~HTML
        <p>Question 1 text</p>
        <p>a) Answer</p>
        <hr/>
        <p>Question 2 text</p>
        <p>a) Answer</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "returns empty array when no hr tags found" do
      html = "<p>Just some regular text</p><p>More text</p>"
      doc = Nokogiri::HTML.fragment(html)
      chunks = described_class.new.split(doc)

      expect(chunks).to eq([])
    end

    it "separates header content before first hr" do
      html = <<~HTML
        <p>Exam header info</p>
        <hr/>
        <p>Question 1 text</p>
        <p>a) Answer</p>
        <hr/>
        <p>Question 2 text</p>
        <p>a) Answer</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(2)
      expect(strategy.header_nodes).not_to be_empty
    end
  end
end
