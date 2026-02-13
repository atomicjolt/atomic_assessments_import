# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor::OptionsDetector do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe "#detect" do
    it "extracts lettered options with paren format" do
      nodes = nodes_from(<<~HTML)
        <p>Question text</p>
        <p>a) Paris</p>
        <p>b) London</p>
        <p>c) Berlin</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result.length).to eq(3)
      expect(result[0][:text]).to eq("Paris")
      expect(result[1][:text]).to eq("London")
      expect(result[2][:text]).to eq("Berlin")
    end

    it "detects correct answer markers with asterisk" do
      nodes = nodes_from(<<~HTML)
        <p>*a) Paris</p>
        <p>b) London</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result[0][:correct]).to be true
      expect(result[1][:correct]).to be false
    end

    it "detects correct answer markers with bold" do
      nodes = nodes_from(<<~HTML)
        <p><strong>a) Paris</strong></p>
        <p>b) London</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result[0][:correct]).to be true
      expect(result[1][:correct]).to be false
    end

    it "returns empty array when no options found" do
      nodes = nodes_from("<p>Just a paragraph</p>")
      result = described_class.new(nodes).detect
      expect(result).to eq([])
    end

    it "handles uppercase letter options" do
      nodes = nodes_from(<<~HTML)
        <p>A) Paris</p>
        <p>B) London</p>
      HTML
      result = described_class.new(nodes).detect
      expect(result.length).to eq(2)
      expect(result[0][:text]).to eq("Paris")
    end
  end
end
