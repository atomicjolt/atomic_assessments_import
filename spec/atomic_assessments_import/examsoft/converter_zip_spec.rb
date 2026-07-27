# frozen_string_literal: true

require "spec_helper"
require "atomic_assessments_import/exam_soft/converter"
require "zip"
require "tempfile"

# Zip support isn't wired into the unified ExamSoft::Converter yet (that's
# Task 5). These examples were moved here, verbatim, from
# oc_tech/converter_spec.rb when that spec was re-pointed at the unified
# converter for single files (Task 4) — they're skipped until Task 5 adds
# the zip branch to `convert`.
RSpec.describe AtomicAssessmentsImport::ExamSoft::Converter do
  let(:good) { File.join(__dir__, "../../fixtures/oc_tech/practice_exam.rtf") }
  let(:bad) { File.join(__dir__, "../../fixtures/oc_tech/no_answers.rtf") }

  describe "zip-wide error indexing", skip: "wired in Task 5" do
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

  describe "zip input", skip: "wired in Task 5" do
    def build_zip(entries)
      file = Tempfile.new(["oc_tech", ".zip"])
      Zip::File.open(file.path, create: true) do |zip|
        entries.each { |name, source| zip.add(name, source) }
      end
      file.path
    end

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
      prose_only = Tempfile.new(["prose_only", ".rtf"])
      prose_only.write(<<~RTF)
        {\\rtf1\\ansi\\ansicpg1252\\deff0\\deflang1033
        {\\fonttbl{\\f0\\froman\\fcharset0 Times New Roman;}}
        \\viewkind4\\uc1\\pard\\f0\\fs24
        This document has no numbered questions in it at all, just prose.\\par
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
  end
end
