# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "atomic_assessments_import/exam_soft/oc_tech/document_parser"

RSpec.describe AtomicAssessmentsImport::ExamSoft::OcTech::DocumentParser do
  def parse(html)
    described_class.parse(Nokogiri::HTML.fragment(html))
  end

  let(:html) { <<~HTML }
    <p><strong>NUR 216 DCT Practice #1</strong></p>
    <p>Date and Time of Exam Creation: 08/31/2024 11:31AM EDT | Total Exam Points: 100 | Est. Completion Time: 13mins</p>
    <p>Avg. Point Biserial: 0.43 | Upper 27%: 1.00 | Difficulty: 0.95 | Total Questions: 2 | Fill in the Blank: 1 | Multiple Choice: 1</p>
    <p><strong>1.</strong></p>
    <p>Order: Dobutamine 5 mcg/kg/min IV.</p>
    <p><em>Question ID: 34334 | Point Value: 20 | Categories:</em></p>
    <p><strong>Answer: 45</strong></p>
    <p><strong>2. A stem that mentions 3. something numeric</strong></p>
    <p>A. 12</p>
    <p><em>Question ID: 23271 | Point Value: 20 | Categories:</em></p>
    <p><strong>Answer: A. 12</strong></p>
  HTML

  it "extracts the title from the first content line" do
    expect(parse(html)[:title]).to eq("NUR 216 DCT Practice #1")
  end

  it "parses declared type counts from the stats line" do
    expect(parse(html)[:declared_counts]).to include(
      "Total Questions" => 2, "Fill in the Blank" => 1, "Multiple Choice" => 1
    )
  end

  it "splits into one block per ascending question number" do
    blocks = parse(html)[:blocks]
    expect(blocks.length).to eq(2)
    expect(blocks[0].first.text).to start_with("1.")
    expect(blocks[1].first.text).to start_with("2.")
    # "3. something numeric" mid-stem must NOT start a block
    expect(blocks[1].map(&:text).join(" ")).to include("3. something numeric")
  end

  it "returns empty blocks and a warning for documents with no numbered questions" do
    result = parse("<p>Just some prose.</p>")
    expect(result[:blocks]).to be_empty
    expect(result[:warnings]).not_to be_empty
  end
end
