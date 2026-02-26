# frozen_string_literal: true

require "atomic_assessments_import"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Extractor do
  def nodes_from(html)
    Nokogiri::HTML.fragment(html).children.to_a
  end

  describe ".extract" do
    it "extracts a complete MCQ question" do
      nodes = nodes_from(<<~HTML)
        <p>Folder: Geography Title: Question 1 Category: Subject/Capitals 1) What is the capital of France? ~ Paris is the capital.</p>
        <p>*a) Paris</p>
        <p>b) London</p>
        <p>c) Berlin</p>
      HTML
      result = described_class.extract(nodes)

      expect(result[:row]["question text"]).to eq("What is the capital of France?")
      expect(result[:row]["option a"]).to eq("Paris")
      expect(result[:row]["option b"]).to eq("London")
      expect(result[:row]["option c"]).to eq("Berlin")
      expect(result[:row]["correct answer"]).to eq("a")
      expect(result[:row]["title"]).to eq("Question 1")
      expect(result[:row]["folder"]).to eq("Geography")
      expect(result[:row]["general feedback"]).to eq("Paris is the capital.")
      expect(result[:row]["question type"]).to eq("mcq")
      expect(result[:status]).to eq("published")
      expect(result[:warnings]).to be_empty
    end

    it "returns non-published status when no correct answer" do
      nodes = nodes_from(<<~HTML)
        <p>1) What is the capital of France?</p>
        <p>a) Paris</p>
        <p>b) London</p>
      HTML
      result = described_class.extract(nodes)

      expect(result[:status]).not_to eq("published")
      expect(result[:warnings]).to include(a_string_matching(/correct answer/i))
    end

    it "returns non-published status when no question text found" do
      nodes = nodes_from(<<~HTML)
        <p>a) Paris</p>
        <p>b) London</p>
      HTML
      result = described_class.extract(nodes)

      expect(result[:status]).not_to eq("published")
      expect(result[:warnings]).to include(a_string_matching(/question text/i))
    end

    it "handles multiple correct answers for MA type" do
      nodes = nodes_from(<<~HTML)
        <p>Type: MA Folder: Geo Title: Q1 Category: Test 1) Pick capitals? ~ Explanation</p>
        <p>*a) Paris</p>
        <p>*b) Berlin</p>
        <p>c) Detroit</p>
      HTML
      result = described_class.extract(nodes)

      expect(result[:row]["correct answer"]).to eq("a; b")
      expect(result[:row]["question type"]).to eq("ma")
    end

    it "extracts essay questions without options" do
      nodes = nodes_from(<<~HTML)
        <p>Type: Essay Folder: Writing Title: Q1 Category: Test 1) Discuss the causes of WWI.</p>
      HTML
      result = described_class.extract(nodes)

      expect(result[:row]["question type"]).to eq("essay")
      expect(result[:row]["question text"]).to eq("Discuss the causes of WWI.")
      expect(result[:status]).to eq("published")
    end

    it "warns and returns non-published status for unsupported question types" do
      nodes = nodes_from(<<~HTML)
        <p>Type: Hotspot 1) Identify the region on the map.</p>
      HTML
      result = described_class.extract(nodes)

      expect(result[:status]).not_to eq("published")
      expect(result[:warnings]).to include(a_string_matching(/unsupported.*hotspot/i))
    end

    it "sets correct answer from options for FITB questions" do
      nodes = nodes_from(<<~HTML)
        <p>Type: F Folder: Science Title: Q1 1) Name the active compound.</p>
        <p>a) Salicin</p>
      HTML
      result = described_class.extract(nodes)

      expect(result[:row]["question type"]).to eq("fill_in_the_blank")
      expect(result[:row]["correct answer"]).to eq("Salicin")
      expect(result[:status]).to eq("published")
    end

  end
end
