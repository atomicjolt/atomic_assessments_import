# frozen_string_literal: true

RSpec.describe AtomicAssessmentsImport do
  it "has a version number" do
    expect(AtomicAssessmentsImport::VERSION).not_to be_nil
  end

  describe "#convert_to_aa_format" do
    it "converts a CSV file to an AA zip archive" do
      input_path = "spec/fixtures/simple.csv"
      out = Tempfile.new("converted")
      out.close(false)

      data = described_class.convert_to_aa_format(input_path, out.path)

      expect(data[:errors]).to be_empty

      Zip::File.open(out.path) do |zip_file|
        expect(zip_file.entries.map(&:name)).to include(
          "export.json",
          match(%r{questions/.+\.json}),
          match(%r{items/.+\.json}),
        )
      end
      out.unlink
    end
  end

  describe "#convert" do
    it "converts a CSV file to an object" do
      input_path = "spec/fixtures/simple.csv"
      data = described_class.convert(input_path, "csv")

      expect(data[:errors]).to be_empty
      expect(data[:items].length).to eq(3)
      expect(data[:questions].length).to eq(3)
    end
  end

  describe "examsoft_octech registration" do
    it "converts an OC Tech RTF end to end" do
      result = described_class.convert(
        File.join(__dir__, "fixtures/oc_tech/practice_exam.rtf"), "examsoft_octech"
      )
      expect(result[:activities].length).to eq(1)
    end

    it "rejects OC Tech files under the classic examsoft source only if type unsupported" do
      expect {
        described_class.convert(File.join(__dir__, "fixtures/simple.csv"), "examsoft_octech")
      }.to raise_error(/Unsupported file type/)
    end
  end
end
