# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::FeedbackDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "extracts feedback after tilde" do
      nodes = nodes_from(<<~HTML)
        <p>1) Question? ~ Paris is the capital.</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result).to eq("Paris is the capital.")
    end

    it "extracts feedback from Explanation: label" do
      nodes = nodes_from(<<~HTML)
        <p>1) Question?</p>
        <p>Explanation: Paris is the capital of France.</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result).to eq("Paris is the capital of France.")
    end

    it "extracts feedback from Rationale: label" do
      nodes = nodes_from(<<~HTML)
        <p>1) Question?</p>
        <p>Rationale: Paris is the capital of France.</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result).to eq("Paris is the capital of France.")
    end

    it "returns nil when no feedback found" do
      nodes = nodes_from("<p>1) What is the capital of France?</p>")
      result = described_class.new(nodes).detect
      expect(result).to be_nil
    end
  end
end
