# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::QuestionTypeDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "detects type from Type: label" do
      nodes = nodes_from("<p>Type: MA Folder: Geography 1) Question?</p>")
      result = described_class.new(nodes, has_options: true).detect
      expect(result).to eq("ma")
    end

    it "detects essay from Type: label" do
      nodes = nodes_from("<p>Type: Essay Folder: Geography 1) Question?</p>")
      result = described_class.new(nodes, has_options: false).detect
      expect(result).to eq("essay")
    end

    it "defaults to mcq when options are present" do
      nodes = nodes_from("<p>1) Question?</p>")
      result = described_class.new(nodes, has_options: true).detect
      expect(result).to eq("mcq")
    end

    it "defaults to short_answer when no options" do
      nodes = nodes_from("<p>1) Question?</p>")
      result = described_class.new(nodes, has_options: false).detect
      expect(result).to eq("short_answer")
    end

    it "detects true/false from Type: label" do
      nodes = nodes_from("<p>Type: True/False 1) Question?</p>")
      result = described_class.new(nodes, has_options: true).detect
      expect(result).to eq("true_false")
    end

    it "detects matching from Type: label" do
      nodes = nodes_from("<p>Type: Matching 1) Question?</p>")
      result = described_class.new(nodes, has_options: true).detect
      expect(result).to eq("matching")
    end

    it "detects ordering from Type: label" do
      nodes = nodes_from("<p>Type: Ordering 1) Question?</p>")
      result = described_class.new(nodes, has_options: true).detect
      expect(result).to eq("ordering")
    end

    it "detects fill_in_the_blank from Type: label" do
      nodes = nodes_from("<p>Type: Fill in the Blank 1) Question?</p>")
      result = described_class.new(nodes, has_options: false).detect
      expect(result).to eq("fill_in_the_blank")
    end
  end
end
