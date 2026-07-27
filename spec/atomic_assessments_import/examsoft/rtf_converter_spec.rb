# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Converter do
  def fixture_path(name)
    File.join("spec/fixtures", name)
  end

  describe "#convert" do
    before(:all) do
      @data = described_class.new("spec/fixtures/simple.rtf").convert
    end

    it "converts a simple RTF file" do
      path = "spec/fixtures/simple.rtf"
      data = described_class.new(path).convert

      expect(data[:activities].length).to eq(1)
      expect(data[:items].length).to eq(3)
      expect(data[:questions].length).to eq(3)
      expect(data[:features]).to eq([])

      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:reference]).not_to be_nil

      item2 = data[:items].find { |i| i[:title] == "Question 2" }
      expect(item2).not_to be_nil
      expect(item2[:reference]).not_to be_nil

      item3 = data[:items].find { |i| i[:title] == "Question 3" }
      expect(item3).not_to be_nil
      expect(item3[:reference]).not_to be_nil

      question1 = data[:questions].find { |q| q[:data][:stimulus] == "What is the capital of France?" }
      expect(question1).not_to be_nil
      expect(question1[:reference]).to eq(item1[:questions][0][:reference])

      question2 = data[:questions].find { |q| q[:data][:stimulus] == "What is the capital of Germany?" }
      expect(question2).not_to be_nil
      expect(question2[:reference]).to eq(item2[:questions][0][:reference])

      question3 = data[:questions].find { |q| q[:data][:stimulus] == "Which are US state capitals?" }
      expect(question3).not_to be_nil
      expect(question3[:reference]).to eq(item3[:questions][0][:reference])
    end

    it "correctly structures question data including options and correct answers" do
      question1 = @data[:questions].find { |q| q[:data][:stimulus] == "What is the capital of France?" }
      expect(question1).not_to be_nil
      
      # Verify basic question structure
      expect(question1[:data][:type]).to eq("mcq")
      expect(question1[:data][:stimulus]).to eq("What is the capital of France?")
      
      # Verify options are structured correctly
      expect(question1[:data][:options]).to be_a(Array)
      expect(question1[:data][:options].length).to be > 0
      expect(question1[:data][:options][0]).to have_key(:label)
      expect(question1[:data][:options][0]).to have_key(:value)
      
      # Verify correct answer is marked
      expect(question1[:data][:validation]).to have_key(:valid_response)
      expect(question1[:data][:validation][:valid_response]).to have_key(:value)
      expect(question1[:data][:validation][:valid_response][:value]).to be_a(Array)
      expect(question1[:data][:validation][:valid_response][:value].length).to be > 0
    end

    it "converts a RTF from a Tempfile" do
      rtf = Tempfile.new(["temp", ".rtf"])
      original_content = File.read("spec/fixtures/simple.rtf")
      rtf.write(original_content)
      rtf.rewind

      data = described_class.new(rtf).convert


      expect(data[:activities].length).to eq(1)
      expect(data[:items].length).to eq(3)
      expect(data[:questions].length).to eq(3)
      expect(data[:features]).to eq([])

      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:reference]).not_to be_nil

      item2 = data[:items].find { |i| i[:title] == "Question 2" }
      expect(item2).not_to be_nil
      expect(item2[:reference]).not_to be_nil

      item3 = data[:items].find { |i| i[:title] == "Question 3" }
      expect(item3).not_to be_nil
      expect(item3[:reference]).not_to be_nil

    end

    it "sets the title and source" do # Currently the converter doesn't set the description since ExamSoft RTF doesn't have a field that maps to it, but we can still test that the title is set correctly and that the source is tagged as coming from ExamSoft.
      item1 = @data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      # expect(item1[:description]).to eq("This is a question about France")
      expect(item1[:title]).to eq("Question 1")
      expect(item1[:source]).to match(/ExamSoft Import/)
    end

    it "sets tags" do
      item1 = @data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:tags]).to eq(
        {
          Subject: ["Capitals"],
          Difficulty: ["Normal"],
        }
      )
    end

    it "sets duplicate tags" do
      item2 = @data[:items].find { |i| i[:title] == "Question 2" }
      expect(item2).not_to be_nil
      expect(item2[:tags]).to eq(
        {
          Subject: %w[Capitals Geography],
        }
      )
    end

    it "warns if no options are given" do
      modified_rtf_file = Tempfile.new(["modified", ".rtf"])
      original_content = File.read("spec/fixtures/simple.rtf")
      modified_content = original_content.gsub(/[a-oA-O]\)\s*[^\}]*/, "")
      modified_rtf_file.write(modified_content)
      modified_rtf_file.rewind

      data = described_class.new(modified_rtf_file).convert
      expect(data[:errors]).to include(a_hash_including(message: a_string_matching(/no options|missing options/i)))
    end

    it "warns if no correct answer is given" do
      modified_rtf_file = Tempfile.new(["temp", ".rtf"])
      original_content = File.read("spec/fixtures/simple.rtf")
      # Only strip the first correct-answer marker (Question 1's) so Questions
      # 2 and 3 still convert — stripping all three would leave zero
      # convertible items and trip the "no questions could be converted"
      # guard instead of exercising this warning.
      modified_content = original_content.sub(/\*([a-oA-O]\))/, '\1')
      modified_rtf_file.write(modified_content)
      modified_rtf_file.rewind

      data = described_class.new(modified_rtf_file).convert
      expect(data[:errors]).to include(a_hash_including(message: a_string_matching(/correct answer/i)))
    end
  end

  describe "activity creation (issue #2237)" do
    it "wraps all items in one activity titled from the filename when no header exists" do
      result = described_class.new(fixture_path("simple.rtf")).convert
      expect(result[:activities].length).to eq(1)
      activity = result[:activities].first
      expect(activity[:title]).to eq("simple")
      expect(activity[:data][:config][:title]).to eq("simple")
      expect(activity[:data][:rendering_type]).to eq("assess")
      expect(activity[:data][:items]).to eq(result[:items].map { |i| { reference: i[:reference], id: i[:reference] } })
    end

    it "prefixes conversion warnings with the filename" do
      result = described_class.new(fixture_path("simple.rtf")).convert
      result[:errors].each { |e| expect(e[:message]).to start_with("simple.rtf: ") }
    end

    it "assigns sequential unique error indexes" do
      result = described_class.new(fixture_path("simple.rtf")).convert
      expect(result[:errors].map { |e| e[:index] }).to eq((0...result[:errors].length).to_a)
    end

    it "raises for files yielding no questions" do
      # ClassicPipeline's single-chunk fallback treats any non-empty stem as
      # a minimal short_answer question (unchanged, pre-existing behavior),
      # so a truly empty document is used here to exercise the zero-items
      # guard rather than prose text, which would still convert to 1 item.
      Tempfile.create(["prose", ".html"]) do |f|
        f.write("<p></p>")
        f.flush
        expect { described_class.new(f.path).convert }
          .to raise_error(AtomicAssessmentsImport::Error, /no questions could be converted/)
      end
    end
  end
end
