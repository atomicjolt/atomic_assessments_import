# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::MetadataDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "extracts folder, title, and category" do
      nodes = nodes_from(<<~HTML)
        <p>Folder: Geography Title: Question 1 Category: Subject/Capitals,Difficulty/Normal 1) Question?</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result[:folder]).to eq("Geography")
      expect(result[:title]).to eq("Question 1")
      expect(result[:categories]).to eq(["Subject/Capitals", "Difficulty/Normal"])
    end

    it "extracts type when present" do
      nodes = nodes_from(<<~HTML)
        <p>Type: MA Folder: Geography Title: Question 1 Category: Subject/Capitals 1) Question?</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result[:type]).to eq("ma")
      expect(result[:folder]).to eq("Geography")
      expect(result[:title]).to eq("Question 1")
      expect(result[:categories]).to eq(["Subject/Capitals"])
    end

    it "does not truncate title at parenthetical numbers like (Q4)" do
      nodes = nodes_from(<<~HTML)
        <p>Type: MA Folder: Geography Title: Question 4 (Q4) Category: Subject/Capitals 4) What are the smallest capital cities?</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result[:title]).to eq("Question 4 (Q4)")
      expect(result[:categories]).to eq(["Subject/Capitals"])
    end

    it "extracts categories spanning multiple lines (line-wrapped by Pandoc)" do
      nodes = nodes_from(<<~HTML)
        <p>Folder: Geography Title: Atlanta Category:
        Capital Categories by State/GA,Capital Categories by Country/United States
        of America,Difficulty/Easy 1) Question?</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result[:categories]).to eq([
        "Capital Categories by State/GA",
        "Capital Categories by Country/United States of America",
        "Difficulty/Easy",
      ])
    end

    it "returns empty hash when no metadata found" do
      nodes = nodes_from("<p>1) What is the capital of France?</p>")
      result = described_class.new(nodes).detect
      expect(result).to eq({})
    end
  end
end
