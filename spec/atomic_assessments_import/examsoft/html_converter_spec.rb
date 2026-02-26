# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::ExamSoft::Converter do
  describe "#convert" do
    before(:all) do
      @data = described_class.new("spec/fixtures/simple.html").convert
    end

    it "converts a simple HTML file" do
      path = "spec/fixtures/simple.html"
      data = described_class.new(path).convert

      expect(data[:activities]).to eq([])
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

    it "converts a HTML from a Tempfile" do
      html = Tempfile.new("temp.html")
      original_content = File.read("spec/fixtures/simple.html")
      html.write(original_content)
      html.rewind
      data = described_class.new(html).convert


      expect(data[:activities]).to eq([])
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
      modified_file = Tempfile.new("modified.html")
      original_content = File.read("spec/fixtures/simple.html")
      # Remove option lines (e.g., "*a) Paris" or "b) Versailles") from the HTML.
      # In HTML, options appear as text within <p> tags, so we remove lines
      # matching the option pattern up to the next tag boundary.
      modified_content = original_content.gsub(/\*?[a-oA-O]\)\s*[^<]*/, "")
      modified_file.write(modified_content)
      modified_file.rewind

      data = described_class.new(modified_file).convert
      expect(data[:errors]).to include(a_hash_including(message: a_string_matching(/no options|missing options/i)))
    end

    it "warns if no correct answer is given" do
      modified_file = Tempfile.new("temp.html")
      original_content = File.read("spec/fixtures/simple.html")
      modified_content = original_content.gsub(/\*([a-oA-O]\))/, '\1')
      modified_file.write(modified_content)
      modified_file.rewind

      data = described_class.new(modified_file).convert
      expect(data[:errors]).to include(a_hash_including(message: a_string_matching(/correct answer/i)))
    end

    it "does not include items with empty definition.widgets in the output" do
      modified_file = Tempfile.new("temp.html")
      original_content = File.read("spec/fixtures/simple.html")
      # Remove asterisk from correct answers so MCQ raises "Missing correct answer"
      # and falls back to convert_row_minimal which produces definition: { widgets: [] }
      modified_content = original_content.gsub(/\*([a-oA-O]\))/, '\1')
      modified_file.write(modified_content)
      modified_file.rewind

      data = described_class.new(modified_file).convert
      # Items with empty definition.widgets cause Learnosity to reject the entire batch
      items_with_empty_widgets = data[:items].select { |i| i[:definition][:widgets].empty? }
      expect(items_with_empty_widgets).to be_empty
    end
  end
end
