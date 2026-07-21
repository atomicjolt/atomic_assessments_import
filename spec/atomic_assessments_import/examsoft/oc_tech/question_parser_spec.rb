# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "atomic_assessments_import/exam_soft/oc_tech/question_parser"

RSpec.describe AtomicAssessmentsImport::ExamSoft::OcTech::QuestionParser do
  def parse(html, number: 1)
    nodes = Nokogiri::HTML.fragment(html).children.reject { |n| n.text? && n.text.strip.empty? }
    described_class.parse(nodes, number)
  end

  it "parses a multiple choice question with metadata and answer" do
    q = parse(<<~HTML)
      <p><strong>1. How many milliliters per dose?</strong></p>
      <p>A. 12</p>
      <p>B. 15</p>
      <p>C. 20</p>
      <p>D. 10</p>
      <p><em>Question ID: 23271 | Point Value: 20 | Point Biserial: .09 | Difficulty: 0.99 | Rationale: 150/15 = 10 | Categories:</em></p>
      <p><strong>Answer: D. 10</strong></p>
    HTML
    expect(q.type).to eq(:multiple_choice)
    expect(q.stem_html).to include("How many milliliters per dose?")
    expect(q.stem_html).not_to include("1.")
    expect(q.options.map { |o| o[:letter] }).to eq(%w[A B C D])
    expect(q.metadata).to include("question id" => "23271", "point value" => "20", "rationale" => "150/15 = 10")
    expect(q.answers).to eq([{ part: nil, text: "D. 10" }])
  end

  it "classifies select-all-that-apply as multiple response" do
    q = parse(<<~HTML)
      <p><strong>1. Which apply? (Select all that apply.)</strong></p>
      <p>A. one</p>
      <p>B. two</p>
      <p><em>Question ID: 1 | Point Value: 4 | Categories:</em></p>
      <p><strong>Answer: A. one</strong></p>
    HTML
    expect(q.type).to eq(:multiple_response)
  end

  it "parses FITB with stem tables and images preserved verbatim" do
    q = parse(<<~HTML)
      <p><strong>1.</strong></p>
      <p><img src="___EXPORT_ROOT___/assets/label.png" alt="image"></p>
      <p>READ THE LABEL ABOVE CAREFULLY</p>
      <table><tr><td>Patient Banner</td></tr></table>
      <p>How many mL? ___________</p>
      <p><em>Question ID: 34643 | Point Value: 20 | Categories:</em></p>
      <p><strong>Answer: 1.7</strong></p>
    HTML
    expect(q.type).to eq(:fitb)
    expect(q.stem_html).to include("<img", "<table>", "READ THE LABEL")
    expect(q.answers).to eq([{ part: nil, text: "1.7" }])
  end

  it "parses multi-part answers" do
    q = parse(<<~HTML)
      <p><strong>1. How long, and what time?</strong></p>
      <p><em>Question ID: 34641 | Point Value: 20 | Categories:</em></p>
      <p><strong>Answer Part 1: 8 hours 20 minutes</strong></p>
      <p><strong>Answer Part 2: 1420</strong></p>
    HTML
    expect(q.type).to eq(:fitb)
    expect(q.answers).to eq([{ part: 1, text: "8 hours 20 minutes" }, { part: 2, text: "1420" }])
  end

  it "parses indexed blank answers (1. value) after a blank marker" do
    q = parse(<<~HTML, number: 18)
      <p><strong>18. How many mL will you administer? ___________</strong></p>
      <p>1. 0, none</p>
      <p><em>Question ID: 36806 | Point Value: 3.33 | Categories:</em></p>
    HTML
    expect(q.type).to eq(:fitb)
    expect(q.answers).to eq([{ part: 1, text: "0, none" }])
  end

  it "parses bowtie response groups" do
    q = parse(<<~HTML)
      <p><strong>1. Scenario text. Drag answers to the boxes.</strong></p>
      <p>Action To Take (choose 2):</p>
      <p>A. act one</p>
      <p>B. act two</p>
      <p>C. act three</p>
      <p>Parameter to Monitor (choose 2):</p>
      <p>A. param one</p>
      <p>B. param two</p>
      <p>Potential Condition (choose 1):</p>
      <p>A. cond one</p>
      <p>B. cond two</p>
    HTML
    expect(q.type).to eq(:bowtie)
    expect(q.groups.map { |g| g[:choose] }).to eq([2, 2, 1])
    expect(q.groups.first[:options].length).to eq(3)
  end

  it "classifies drag-the-correct-answer stems" do
    q = parse(<<~HTML)
      <p><strong>1. Which are appropriate? (drag the correct answer to the right side of the page)</strong></p>
      <p>A. one</p>
      <p>B. two</p>
      <p><em>Question ID: 5 | Point Value: 4 | Categories:</em></p>
      <p><strong>Answer: A. one</strong></p>
    HTML
    expect(q.type).to eq(:drag_and_drop)
  end

  it "marks blocks with neither options nor answers as unknown" do
    q = parse("<p><strong>1. A stem only.</strong></p>")
    expect(q.type).to eq(:unknown)
    expect(q.warnings).not_to be_empty
  end
end
