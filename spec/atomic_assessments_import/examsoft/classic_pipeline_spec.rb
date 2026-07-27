# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "atomic_assessments_import/exam_soft/classic_pipeline"

RSpec.describe AtomicAssessmentsImport::ExamSoft::ClassicPipeline do
  it "converts classic chunks and reports the header as the title" do
    doc = Nokogiri::HTML.fragment(<<~HTML)
      <p>Geography Midterm</p>
      <hr>
      <p>Folder: Geography Title: Q1 Category: Subject/Capitals 1) What is the capital of France?</p>
      <p>*a) Paris</p>
      <p>b) Versailles</p>
    HTML
    result = described_class.convert_document(doc)
    expect(result[:items].length).to eq(1)
    expect(result[:questions].first[:data][:type]).to eq("mcq")
    expect(result[:features]).to eq([])
    expect(result[:errors]).to all(include(qti_item_id: nil))
  end

  it "returns nil title when there is no header" do
    doc = Nokogiri::HTML.fragment(<<~HTML)
      <p>Folder: G Title: Q1 Category: S/C 1) Capital of France?</p>
      <p>*a) Paris</p>
      <p>b) Versailles</p>
    HTML
    expect(described_class.convert_document(doc)[:title]).to be_nil
  end
end
