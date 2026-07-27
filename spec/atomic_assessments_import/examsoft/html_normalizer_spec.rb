# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe AtomicAssessmentsImport::ExamSoft::HtmlNormalizer do
  it "splits paragraphs at <br> into separate paragraphs" do
    doc = Nokogiri::HTML.fragment("<p>one<br>two<br>three</p>")
    described_class.normalize!(doc)
    expect(doc.css("p").map(&:text)).to eq(%w[one two three])
  end

  it "leaves paragraphs without <br> untouched" do
    doc = Nokogiri::HTML.fragment("<p><strong>1.</strong> stem</p>")
    described_class.normalize!(doc)
    expect(doc.to_html).to include("<strong>1.</strong>")
  end
end
