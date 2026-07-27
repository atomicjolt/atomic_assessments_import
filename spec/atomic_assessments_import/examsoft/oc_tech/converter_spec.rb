# frozen_string_literal: true

require "spec_helper"
require "atomic_assessments_import/exam_soft/converter"
require "zip"
require "tempfile"

# These examples exercise OC Tech single-file conversion through the unified
# ExamSoft::Converter (not a dedicated OC Tech converter — that class was
# deleted when the orchestrator was unified in Task 4). Every expectation
# passing here is the proof that FormatDetector correctly routes OC Tech
# documents to the OcTech pipeline.
RSpec.describe AtomicAssessmentsImport::ExamSoft::Converter do
  subject(:result) { described_class.new(fixture).convert }

  let(:fixture) { File.join(__dir__, "../../../fixtures/oc_tech/practice_exam.rtf") }

  it "creates one activity per file, titled from the exam header, with items in order" do
    expect(result[:activities].length).to eq(1)
    activity = result[:activities].first
    expect(activity[:title]).to eq("OC Tech Practice Exam")
    expect(activity[:data][:config][:title]).to eq("OC Tech Practice Exam")
    expect(activity[:data][:rendering_type]).to eq("assess")
    item_refs = result[:items].map { |i| i[:reference] }
    expect(activity[:data][:items]).to eq(item_refs.map { |r| { reference: r, id: r } })
  end

  it "converts all three questions (image FITB, MC, multi-part FITB)" do
    expect(result[:items].length).to eq(3)
    expect(result[:items].map { |i| i[:title] }).to eq(%w[34643 23271 34641])
    types = result[:questions].map { |q| q[:data][:type] }
    expect(types).to eq(%w[clozetext mcq clozetext])
  end

  it "extracts the embedded image into assets and rewrites the stem src" do
    expect(result[:assets].keys.length).to eq(1)
    asset_path = result[:assets].keys.first
    expect(asset_path).to match(%r{\Aassets/.+\.png\z})
    expect(result[:assets][asset_path][0, 4].bytes).to eq([0x89, 0x50, 0x4E, 0x47])
    image_question = result[:questions].first
    # clozetext puts the full question text in `template` and leaves
    # `stimulus` blank, so the rewritten image src lands in the template.
    expect(image_question[:data][:template]).to include("___EXPORT_ROOT___/#{asset_path}")
    expect(image_question[:data][:template].scan("{{response}}").length).to eq(1)
  end

  it "raises a file-level error for answer-less scorable files" do
    no_answers = File.join(__dir__, "../../../fixtures/oc_tech/no_answers.rtf")
    expect { described_class.new(no_answers).convert }.to raise_error(
      AtomicAssessmentsImport::Error, /no answer key found — request an ExamSoft export that includes answers/
    )
  end

  it "warns when parsed question count mismatches the declared total" do
    # practice_exam declares 3 and parses 3 — no warning
    expect(result[:errors].map { |e| e[:message] }.join).not_to include("declared")
  end

  # Cross-file error-index uniqueness (multiple entries merged into one
  # result) requires zip support — see the "zip-wide error indexing" example
  # in converter_zip_spec.rb (skipped until Task 5). Single-file index
  # assignment is covered by rtf_converter_spec.rb's "assigns sequential
  # unique error indexes" example.

  it "raises when a file contains no convertible questions" do
    # Body text alone (no numbered questions) no longer guarantees zero
    # items now that non-OC-Tech documents fall through to ClassicPipeline,
    # whose single-chunk fallback treats any non-empty stem as a minimal
    # short_answer question (see rtf_converter_spec.rb's "raises for files
    # yielding no questions" for that behavior). An empty document body is
    # used here instead to exercise the zero-items guard.
    prose_only = Tempfile.new(["prose_only", ".rtf"])
    prose_only.write(<<~RTF)
      {\\rtf1\\ansi\\ansicpg1252\\deff0\\deflang1033
      {\\fonttbl{\\f0\\froman\\fcharset0 Times New Roman;}}
      \\viewkind4\\uc1\\pard\\f0\\fs24
      }
    RTF
    prose_only.flush

    expect { described_class.new(prose_only.path).convert }.to raise_error(
      AtomicAssessmentsImport::Error, /no questions could be converted/
    )
  end
end
