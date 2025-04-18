# frozen_string_literal: true

RSpec.describe AtomicAssessmentsImport::CSV::Converter do
  describe "#convert" do
    it "converts a simple CSV file" do
      path = "spec/fixtures/simple.csv"
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

    it "converts a CSV from a string IO" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Question Text,Option A, Option B,Option C,Correct Answer,template
        Q001,Question 1,Capitals,What is the capital of France?,Paris, Versailles,Bordeaux,A,
        Q002,Question 2,Capitals,What is the capital of Germany?,Berlin, Bonn, Brandenburg,A,Multiple choice
      CSV
      data = described_class.new(StringIO.new(csv)).convert

      expect(data[:activities]).to eq([])
      expect(data[:items].length).to eq(2)
      expect(data[:questions].length).to eq(2)
      expect(data[:features]).to eq([])

      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:reference]).not_to be_nil

      item2 = data[:items].find { |i| i[:title] == "Question 2" }
      expect(item2).not_to be_nil
      expect(item2[:reference]).not_to be_nil
    end

    it "sets the description and title" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Question Text,Option A, Option B,Option C,Correct Answer,template,description
        Q001,Question 1,Capitals,What is the capital of France?,Paris, Versailles,Bordeaux,A,,This is a question about France
      CSV
      data = described_class.new(StringIO.new(csv)).convert
      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:description]).to eq("This is a question about France")
      expect(item1[:title]).to eq("Question 1")
      expect(item1[:source]).to match(/CSV Import/)
    end

    it "sets tags" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Tag:Difficulty,Question Text,Option A, Option B,Option C,Correct Answer
        Q001,Question 1,Capitals,Normal,What is the capital of France?,Paris, Versailles,Bordeaux,A
      CSV
      data = described_class.new(StringIO.new(csv)).convert
      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:tags]).to eq(
        {
          Subject: ["Capitals"],
          Difficulty: ["Normal"],
        }
      )
    end

    it "sets duplicate tags" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Tag:Subject,Question Text,Option A, Option B,Option C,Correct Answer
        Q001,Question 1,Capitals,Geography,What is the capital of France?,Paris, Versailles,Bordeaux,A
      CSV
      data = described_class.new(StringIO.new(csv)).convert
      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:tags]).to eq(
        {
          Subject: %w[Capitals Geography],
        }
      )
    end

    it "sets external id metadata" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Question Text,Option A, Option B,Option C,Correct Answer
        Q001,Question 1,Capitals,What is the capital of France?,Paris, Versailles,Bordeaux,A
      CSV
      data = described_class.new(StringIO.new(csv)).convert
      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:metadata][:external_id]).to eq("Q001")
      expect(item1[:metadata][:external_id_domain]).to eq("csv")
      expect(item1[:metadata][:import_type]).to eq("csv")
      expect(item1[:source]).to match(/External.*Q001/)
    end

    it "sets alignment tags" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Question Text,Option A, Option B,Option C,Correct Answer,Alignment URL
        Q001,Question 1,Capitals,What is the capital of France?,Paris, Versailles,Bordeaux,A,"https://example.com/alignment"
      CSV
      data = described_class.new(StringIO.new(csv)).convert
      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:tags]).to eq(
        {
          Subject: ["Capitals"],
          lrn_aligned: ["ff8a5caa-0f2a-5a53-a128-c8c3e99768a8"],
        }
      )
      expect(item1[:metadata][:alignment]).to eq(%w[https://example.com/alignment])
    end

    it "sets multiple alignment tags" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Question Text,Option A, Option B,Option C,Correct Answer,Alignment URL,Alignment URL
        Q001,Question 1,Capitals,What is the capital of France?,Paris, Versailles,Bordeaux,A,https://example.com/alignment,https://example.com/alignment2
      CSV
      data = described_class.new(StringIO.new(csv)).convert
      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:tags]).to eq(
        {
          Subject: ["Capitals"],
          lrn_aligned: %w[ff8a5caa-0f2a-5a53-a128-c8c3e99768a8 f7d26914-3e2b-5c9c-a550-ce9c853f0c09],
        }
      )
      expect(item1[:metadata][:alignment]).to eq(%w[https://example.com/alignment https://example.com/alignment2])
    end

    it "sets alignment tags when one is empty" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Question Text,Option A, Option B,Option C,Correct Answer,Alignment URL,Alignment URL
        Q001,Question 1,Capitals,What is the capital of France?,Paris, Versailles,Bordeaux,A,,https://example.com/alignment2
      CSV
      data = described_class.new(StringIO.new(csv)).convert
      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:tags]).to eq(
        {
          Subject: ["Capitals"],
          lrn_aligned: %w[f7d26914-3e2b-5c9c-a550-ce9c853f0c09],
        }
      )
      expect(item1[:metadata][:alignment]).to eq(%w[https://example.com/alignment2])
    end

    it "raises if an unknown header is present" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Question Text,Option A, Option B,Option C,Correct Answer,Color
        Q001,Question 1,Capitals,What is the capital of France?,Paris, Versailles,Bordeaux,A,
      CSV
      expect do
        described_class.new(StringIO.new(csv)).convert
      end.to raise_error(StandardError, "Unknown column: Color")
    end

    it "raises if no options are given" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Question Text,Option A, Option B,Option C,Correct Answer
        Q001,Question 1,Capitals,What is the capital of France?,,,,A
      CSV
      expect do
        described_class.new(StringIO.new(csv)).convert
      end.to raise_error(StandardError, /Missing options/)
    end

    it "raises if no correct answer is given" do
      csv = <<~CSV
        Question ID,Title,Tag:Subject,Question Text,Option A, Option B,Option C
        Q001,Question 1,Capitals,What is the capital of France?,Paris, Versailles,Bordeaux
      CSV
      expect do
        described_class.new(StringIO.new(csv)).convert
      end.to raise_error(StandardError, /Missing correct answer/)
    end
  end
end
