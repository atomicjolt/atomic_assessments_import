# frozen_string_literal: true

require "spec_helper"
require "atomic_assessments_import/exam_soft/oc_tech/converter"
require "zip"
require "tempfile"

RSpec.describe AtomicAssessmentsImport::ExamSoft::OcTech::Converter do
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
    expect(types).to eq(%w[shorttext mcq shorttext shorttext])
  end

  it "extracts the embedded image into assets and rewrites the stem src" do
    expect(result[:assets].keys.length).to eq(1)
    asset_path = result[:assets].keys.first
    expect(asset_path).to match(%r{\Aassets/.+\.png\z})
    expect(result[:assets][asset_path][0, 4].bytes).to eq([0x89, 0x50, 0x4E, 0x47])
    image_question = result[:questions].first
    expect(image_question[:data][:stimulus]).to include("___EXPORT_ROOT___/#{asset_path}")
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

  describe "zip input" do
    def build_zip(entries)
      file = Tempfile.new(["oc_tech", ".zip"])
      Zip::File.open(file.path, create: true) do |zip|
        entries.each { |name, source| zip.add(name, source) }
      end
      file.path
    end

    let(:good) { File.join(__dir__, "../../../fixtures/oc_tech/practice_exam.rtf") }
    let(:bad) { File.join(__dir__, "../../../fixtures/oc_tech/no_answers.rtf") }

    it "creates one activity per successful entry and isolates failures" do
      zip = build_zip("good.rtf" => good, "bad.rtf" => bad, "notes.txt" => good, "__MACOSX/x.rtf" => good)
      result = described_class.new(zip).convert
      expect(result[:activities].length).to eq(1)
      expect(result[:items].length).to eq(3)
      file_errors = result[:errors].select { |e| e[:error_type] == "error" }
      expect(file_errors.map { |e| e[:message] }.join).to include("bad.rtf", "no answer key found")
      expect(result[:errors].map { |e| e[:message] }.join).to include("notes.txt")
    end

    it "raises when no entry converts successfully" do
      zip = build_zip("bad.rtf" => bad)
      expect { described_class.new(zip).convert }.to raise_error(AtomicAssessmentsImport::Error)
    end
  end
end
