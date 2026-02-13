# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Chunker::MetadataMarkerStrategy do
  describe "#split" do
    it "splits HTML on Folder: markers" do
      html = <<~HTML
        <p>Folder: Geography Title: Q1 Category: Test 1) What is the capital? ~ Explanation</p>
        <p>*a) Paris</p>
        <p>b) London</p>
        <p>Folder: Science Title: Q2 Category: Test 2) What is H2O? ~ Water</p>
        <p>*a) Water</p>
        <p>b) Fire</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "splits HTML on Type: markers" do
      html = <<~HTML
        <p>Type: MA Title: Q1 Category: Test 1) Question? ~ Expl</p>
        <p>*a) Answer</p>
        <p>Type: MCQ Title: Q2 Category: Test 2) Question2? ~ Expl</p>
        <p>*a) Answer2</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(2)
    end

    it "returns empty array when no markers found" do
      html = "<p>Just some text with no markers</p>"
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks).to eq([])
    end

    it "separates exam header from questions" do
      html = <<~HTML
        <p>Exam: Midterm 2024</p>
        <p>Total Questions: 30</p>
        <p>Folder: Geography Title: Q1 Category: Test 1) Question? ~ Expl</p>
        <p>*a) Answer</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(1)
      expect(strategy.header_nodes).not_to be_empty
    end

    it "returns chunks as arrays of Nokogiri nodes" do
      html = <<~HTML
        <p>Folder: Geo Title: Q1 Category: Test 1) Question? ~ Expl</p>
        <p>*a) Answer</p>
        <p>b) Wrong</p>
      HTML
      doc = Nokogiri::HTML.fragment(html)
      strategy = described_class.new
      chunks = strategy.split(doc)

      expect(chunks.length).to eq(1)
      expect(chunks[0]).to all(be_a(Nokogiri::XML::Node))
    end
  end
end
