# frozen_string_literal: true

require "spec_helper"
require "zip"
require "tempfile"

RSpec.describe AtomicAssessmentsImport::Export do
  def read_zip(path)
    entries = {}
    Zip::File.open(path) { |z| z.each { |e| entries[e.name] = e.get_input_stream.read } }
    entries
  end

  it "writes assets and features into the archive" do
    Tempfile.create(["export", ".zip"]) do |f|
      described_class.create(f.path, {
        activities: [], items: [], questions: [],
        features: [{ reference: "feat-1", data: { type: "sharedpassage" } }],
        assets: { "assets/label.png" => "PNGBYTES".b },
      })
      entries = read_zip(f.path)
      expect(entries.keys).to include("assets/label.png", "features/feat-1.json", "export.json")
      expect(entries["assets/label.png"]).to eq("PNGBYTES")
    end
  end

  it "tolerates result hashes without assets or features keys" do
    Tempfile.create(["export", ".zip"]) do |f|
      expect {
        described_class.create(f.path, { activities: [], items: [], questions: [] })
      }.not_to raise_error
    end
  end
end
