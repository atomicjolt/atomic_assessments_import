# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Chunker do
  describe ".chunk" do
    it "uses MetadataMarkerStrategy when Folder: markers are present" do
      html = <<~HTML
        <p>Folder: Geo Title: Q1 Category: Test 1) Question? ~ Expl</p>
        <p>*a) Answer</p>
        <p>Folder: Sci Title: Q2 Category: Test 2) Question2? ~ Expl</p>
        <p>*a) Answer2</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      result = described_class.chunk(doc)

      expect(result[:chunks].length).to eq(2)
    end

    it "falls back to NumberedQuestionStrategy when no metadata markers" do
      html = <<~HTML
        <p>1) What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
        <p>2) What is H2O?</p>
        <p>a) Water</p>
        <p>b) Fire</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      result = described_class.chunk(doc)

      expect(result[:chunks].length).to eq(2)
    end

    it "falls back to HeadingSplitStrategy when no numbers" do
      html = <<~HTML
        <h2>Question 1</h2>
        <p>What is the capital?</p>
        <p>a) Paris</p>
        <h2>Question 2</h2>
        <p>What is H2O?</p>
        <p>a) Water</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      result = described_class.chunk(doc)

      expect(result[:chunks].length).to eq(2)
    end

    it "returns whole document as single chunk when no strategy matches" do
      html = <<~HTML
        <p>Some question text here</p>
        <p>a) An option</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      result = described_class.chunk(doc)

      expect(result[:chunks].length).to eq(1)
      expect(result[:warnings]).to include(a_string_matching(/no chunking strategy/i))
    end

    it "extracts header nodes" do
      html = <<~HTML
        <p>Exam: Midterm 2024</p>
        <p>Total Questions: 30</p>
        <p>Folder: Geo Title: Q1 Category: Test 1) Question? ~ Expl</p>
        <p>*a) Answer</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      result = described_class.chunk(doc)

      expect(result[:header_nodes]).not_to be_empty
    end
  end
end
