# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe "ExamSoft Integration" do
  describe "mixed question types" do
    it "handles a document with MCQ, essay, and MA questions" do
      data = AtomicAssessmentsImport::ExamSoft::Converter.new("spec/fixtures/mixed_types.html").convert

      expect(data[:items].length).to eq(4)

      # MCQ question
      q1 = data[:questions].find { |q| q[:data][:stimulus]&.include?("powerhouse") }
      expect(q1).not_to be_nil
      expect(q1[:type]).to eq("mcq")

      # Essay question
      q2 = data[:questions].find { |q| q[:data][:stimulus]&.include?("Hamlet") }
      expect(q2).not_to be_nil
      expect(q2[:type]).to eq("longanswer")

      # MA question
      q3 = data[:questions].find { |q| q[:data][:stimulus]&.include?("European capitals") }
      expect(q3).not_to be_nil
      expect(q3[:type]).to eq("mcq")  # MA maps to mcq with multiple_responses

      # Another MCQ
      q4 = data[:questions].find { |q| q[:data][:stimulus]&.include?("chemical symbol") }
      expect(q4).not_to be_nil
      expect(q4[:type]).to eq("mcq")
    end

    it "reports exam header in warnings" do
      data = AtomicAssessmentsImport::ExamSoft::Converter.new("spec/fixtures/mixed_types.html").convert
      expect(data[:errors]).to include(a_string_matching(/header/i))
    end
  end

  describe "messy documents with partial parse" do
    it "imports what it can and warns about problems" do
      data = AtomicAssessmentsImport::ExamSoft::Converter.new("spec/fixtures/messy_document.html").convert

      # Should get at least 2 good items (Q1 and Q3 have options)
      published = data[:items].select { |i| i[:status] == "published" }
      expect(published.length).to be >= 2

      # Should have warnings about Q2 (no options for what looks like MCQ)
      expect(data[:errors].length).to be > 0
    end
  end

  describe "backward compatibility" do
    it "produces the same structure from simple.html as before" do
      data = AtomicAssessmentsImport::ExamSoft::Converter.new("spec/fixtures/simple.html").convert

      expect(data[:items].length).to eq(3)
      expect(data[:questions].length).to eq(3)
      expect(data[:activities]).to eq([])
      expect(data[:features]).to eq([])

      item1 = data[:items].find { |i| i[:title] == "Question 1" }
      expect(item1).not_to be_nil
      expect(item1[:status]).to eq("published")

      q1 = data[:questions].find { |q| q[:data][:stimulus] == "What is the capital of France?" }
      expect(q1).not_to be_nil
      expect(q1[:data][:options].length).to eq(3)
    end
  end
end
