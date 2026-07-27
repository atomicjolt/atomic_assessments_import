# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "atomic_assessments_import/exam_soft/format_detector"

RSpec.describe AtomicAssessmentsImport::ExamSoft::FormatDetector do
  def detect(html)
    described_class.detect(Nokogiri::HTML.fragment(html))&.fetch(:name)
  end

  it "detects OC Tech via the stats header line" do
    expect(detect(<<~HTML)).to eq(:oc_tech)
      <p>NUR 216 DCT Practice #1</p>
      <p>Avg. Point Biserial: 0.43 | Difficulty: 0.95 | Total Questions: 5 | Fill in the Blank: 5</p>
      <p><strong>1.</strong></p>
      <p>Order: Dobutamine 5 mcg/kg/min IV.</p>
    HTML
  end

  it "detects OC Tech via Question ID metadata lines even without a stats header" do
    expect(detect(<<~HTML)).to eq(:oc_tech)
      <p><strong>1. How many mL?</strong></p>
      <p><em>Question ID: 23271 | Point Value: 20 | Categories:</em></p>
      <p><strong>Answer: 10</strong></p>
    HTML
  end

  it "does not detect OC Tech from a stats-like line after the first question" do
    expect(detect(<<~HTML)).to be_nil
      <p><strong>1. The stem discusses survey design.</strong></p>
      <p>Respondents were asked: Total Questions: 40 in the booklet.</p>
    HTML
  end

  it "does not detect OC Tech from a non-piped 'Total Questions' line before question 1" do
    expect(detect(<<~HTML)).to be_nil
      <p>Exam: Midterm 2024</p>
      <p>Total Questions: 4</p>
      <p>Folder: Science Title: Q1 Category: Biology/Cells 1) What is the powerhouse of the cell?</p>
      <p>*a) Mitochondria</p>
      <p>b) Nucleus</p>
    HTML
  end

  it "returns nil for classic-format content" do
    expect(detect(<<~HTML)).to be_nil
      <p>Folder: Geography Title: Question 1 Category: Subject/Capitals 1) What is the capital of France?</p>
      <p>*a) Paris</p>
      <p>b) Versailles</p>
    HTML
  end

  it "returns nil for unrecognized prose" do
    expect(detect("<p>Just some prose about nursing.</p>")).to be_nil
  end
end
