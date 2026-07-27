# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "atomic_assessments_import/exam_soft/oc_tech"

RSpec.describe "AtomicAssessmentsImport::ExamSoft::OcTech.convert_document" do
  let(:mod) { AtomicAssessmentsImport::ExamSoft::OcTech }

  let(:doc) do
    Nokogiri::HTML.fragment(<<~HTML)
      <p><strong>OC Tech Practice Exam</strong></p>
      <p>Avg. Point Biserial: 0.4 | Difficulty: 0.9 | Total Questions: 2 | Multiple Choice: 1 | Fill in the Blank: 1</p>
      <p><strong>1. How many milliliters per dose?</strong></p>
      <p>A. 12</p>
      <p>B. 10</p>
      <p><em>Question ID: 23271 | Point Value: 20 | Categories:</em></p>
      <p><strong>Answer: B. 10</strong></p>
      <p><strong>2. How many mL? ___________</strong></p>
      <p><em>Question ID: 34643 | Point Value: 20 | Categories:</em></p>
      <p><strong>Answer: 1.7</strong></p>
    HTML
  end

  it "returns the pipeline contract with unprefixed error messages" do
    result = mod.convert_document(doc)
    expect(result[:title]).to eq("OC Tech Practice Exam")
    expect(result[:items].length).to eq(2)
    expect(result[:questions].map { |q| q[:data][:type] }).to eq(%w[mcq clozetext])
    expect(result[:features]).to eq([])
    result[:errors].each do |e|
      expect(e).to include(error_type: anything, message: anything, qti_item_id: nil)
      expect(e[:message]).not_to include(":  ") # no filename prefix artifacts
    end
  end

  it "raises MissingAnswerError for answer-less scorable questions" do
    answerless = Nokogiri::HTML.fragment(
      "<p>T</p><p>Total Questions: 1 | Multiple Choice: 1</p>" \
      "<p><strong>1. Which?</strong></p><p>A. one</p><p>B. two</p>"
    )
    expect { mod.convert_document(answerless) }
      .to raise_error(AtomicAssessmentsImport::ExamSoft::OcTech::ItemBuilder::MissingAnswerError)
  end
end
