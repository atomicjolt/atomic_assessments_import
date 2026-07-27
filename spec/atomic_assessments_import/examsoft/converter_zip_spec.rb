# frozen_string_literal: true

require "spec_helper"
require "atomic_assessments_import/exam_soft/converter"
require "zip"
require "tempfile"

# Zip support for the unified ExamSoft::Converter: classic files, OC Tech
# files, and a mix of both in the same zip, each entry routed through its own
# pipeline via FormatDetector (same semantics as the old, now-deleted, OC
# Tech-only zip path).
RSpec.describe AtomicAssessmentsImport::ExamSoft::Converter do
  let(:good) { File.join(__dir__, "../../fixtures/oc_tech/practice_exam.rtf") }
  let(:bad) { File.join(__dir__, "../../fixtures/oc_tech/no_answers.rtf") }

  def fixture(name)
    File.join(__dir__, "../../fixtures", name)
  end

  def build_zip(entries)
    file = Tempfile.new(["examsoft", ".zip"])
    Zip::File.open(file.path, create: true) do |zip|
      entries.each { |name, source| zip.add(name, source) }
    end
    file.path
  end

  describe "zip-wide error indexing" do
    it "assigns each error a distinct sequential index so none collide on find_or_create_by" do
      # Build a scenario with 2+ errors via a zip: a good entry (so the zip
      # doesn't raise), a failing entry, and an unsupported entry, all of which
      # land in the merged errors array.
      zip_file = Tempfile.new(["oc_tech_indexes", ".zip"])
      Zip::File.open(zip_file.path, create: true) do |zip|
        zip.add("good.rtf", good)
        zip.add("bad.rtf", bad)
        zip.add("notes.txt", good)
      end

      zip_result = described_class.new(zip_file.path).convert
      indexes = zip_result[:errors].map { |e| e[:index] }
      expect(indexes.length).to be >= 2
      expect(indexes).to eq(indexes.uniq)
      expect(indexes).to eq((0...indexes.length).to_a)
    end
  end

  describe "zip input" do
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

    it "raises when a zip contains only a file with no convertible questions" do
      # ClassicPipeline's single-chunk fallback treats any non-empty stem as
      # a minimal short_answer question (see rtf_converter_spec.rb's "raises
      # for files yielding no questions"), so a truly empty document is used
      # here instead of prose text to exercise the zero-items guard.
      prose_only = Tempfile.new(["prose_only", ".rtf"])
      prose_only.write(<<~RTF)
        {\\rtf1\\ansi\\ansicpg1252\\deff0\\deflang1033
        {\\fonttbl{\\f0\\froman\\fcharset0 Times New Roman;}}
        \\viewkind4\\uc1\\pard\\f0\\fs24
        }
      RTF
      prose_only.flush

      zip = build_zip("prose_only.rtf" => prose_only.path)
      expect { described_class.new(zip).convert }.to raise_error(
        AtomicAssessmentsImport::Error, /No files in the zip could be converted/
      )
    end

    it "converts two good entries into two activities with merged items and assets" do
      zip = build_zip("first.rtf" => good, "second.rtf" => good)
      result = described_class.new(zip).convert

      expect(result[:activities].length).to eq(2)
      expect(result[:items].length).to eq(6)
      # Both entries embed the same source image, so asset keys (derived from
      # basename) collide on merge — assert assets are present rather than
      # asserting an exact count of 2 distinct keys.
      expect(result[:assets]).not_to be_empty
    end

    it "isolates a non-gem exception (e.g. a corrupt docx) instead of aborting the whole zip" do
      corrupt = Tempfile.new(["corrupt", ".docx"])
      corrupt.write("not a docx")
      corrupt.flush

      zip = build_zip("good.rtf" => good, "corrupt.docx" => corrupt.path)

      result = nil
      expect { result = described_class.new(zip).convert }.not_to raise_error

      expect(result[:activities].length).to eq(1)
      file_errors = result[:errors].select { |e| e[:error_type] == "error" }
      expect(file_errors.map { |e| e[:message] }.join).to include("corrupt.docx")
    end

    it "converts a zip of classic files into one activity per entry" do
      zip = build_zip("geo.rtf" => fixture("simple.rtf"), "mixed.docx" => fixture("simple.docx"))
      result = described_class.new(zip).convert
      expect(result[:activities].map { |a| a[:title] }).to contain_exactly("geo", "mixed")
    end

    it "converts a mixed classic + OC Tech zip, each via its own pipeline" do
      zip = build_zip(
        "classic.rtf" => fixture("simple.rtf"),
        "octech.rtf" => fixture("oc_tech/practice_exam.rtf"),
      )
      result = described_class.new(zip).convert
      expect(result[:activities].length).to eq(2)
      octech_activity = result[:activities].find { |a| a[:title] == "OC Tech Practice Exam" }
      expect(octech_activity).not_to be_nil # OC Tech title from header, classic from filename
      types = result[:questions].map { |q| q[:data][:type] }
      expect(types).to include("clozetext") # OC Tech FITB parsed by OC Tech pipeline
      expect(result[:assets].keys).to all(match(%r{\Aassets/}))
      expect(result[:errors].map { |e| e[:index] }.uniq.length).to eq(result[:errors].length)
    end
  end
end
