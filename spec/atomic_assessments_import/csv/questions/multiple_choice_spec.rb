# frozen_string_literal: true

RSpec.describe AtomicAssessmentsImport::CSV::Questions::MultipleChoice do
  describe "#to_learnosity" do
    let(:template) { "Multiple choice" }
    let(:correct_answer) { "A" }
    let(:data) do
      {
        'question id': "Q001",
        'title': "Question 1",
        'tag:Subject': "Capitals",
        'tag:Language': "English",
        'question text': "What is the capital of France?",
        'option a': "Paris",
        'option b': "Versailles",
        'option c': "Bordeaux",
        'correct answer': correct_answer,
        'template': template,
        'option a feedback': "Paris is the capital of France",
        'option b feedback': "Versailles is not the capital of France",
        'option c feedback': "Bordeaux is not the capital of France",
        'general feedback': "Good job!",
        'correct feedback': "Correct!",
        'partially correct feedback': "Partially correct!",
        'incorrect feedback': "Incorrect!",
        'distractor rationale': "Distractor rationale",
        'sample answer': "Sample answer",
        'acknowledgements': "Acknowledgements",
        'stimulus review': "Stimulus review",
        'instructor stimulus': "Instructor stimulus",
        'points': "2",
        'scoring type': "Partial Match Per Response",
        'question type': "Multiple choice",
        'shuffle options': "yes",
      }
    end
    let(:row) { CSV::Row.new(data.keys.map(&:to_s), data.values) }

    it "creates a mcq question" do
      question = described_class.new(row)
      expect(question.to_learnosity).not_to be_nil
    end

    it "sets the type to mcq" do
      question = described_class.new(row)
      expect(question.to_learnosity[:type]).to eq("mcq")
    end

    it "sets the widget type to response" do
      question = described_class.new(row)
      expect(question.to_learnosity[:widget_type]).to eq("response")
    end

    it "sets the reference" do
      question = described_class.new(row)
      expect(question.to_learnosity[:reference]).to eq(question.reference)
    end

    it "sets the data" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data]).to eq(question.question_data)
    end

    it "sets the stimulus" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:stimulus]).to eq("What is the capital of France?")
    end

    it "sets the metadata" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:metadata]).to eq(question.metadata)
    end

    it "sets the stimulus review" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:stimulus_review]).to eq("Stimulus review")
    end

    it "sets the instructor stimulus" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:instructor_stimulus]).to eq("Instructor stimulus")
    end

    it "sets the multiple responses" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:multiple_responses]).to be_falsey
    end

    it "sets the scoring type" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:validation][:scoring_type]).to eq("partialMatchV2")
    end

    it "sets the points" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:validation][:valid_response][:score]).to eq(2)
    end

    it "sets the correct answer" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:validation][:valid_response][:value]).to eq(["0"])
    end

    it "sets the options" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:options]).to eq(
        [
          { label: "Paris", value: "0" },
          { label: "Versailles", value: "1" },
          { label: "Bordeaux", value: "2" },
        ]
      )
    end

    it "sets the distractor rationale" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:metadata][:distractor_rationale]).to eq("Distractor rationale")
    end

    it "sets the sample answer" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:metadata][:sample_answer]).to eq("Sample answer")
    end

    it "sets the acknowledgements" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:metadata][:acknowledgements]).to eq("Acknowledgements")
    end

    it "sets the general feedback" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:metadata][:general_feedback]).to eq("Good job!")
    end

    it "sets the correct feedback" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:metadata][:correct_feedback]).to eq("Correct!")
    end

    it "sets the partially correct feedback" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:metadata][:partially_correct_feedback]).to eq("Partially correct!")
    end

    it "sets the incorrect feedback" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:metadata][:incorrect_feedback]).to eq("Incorrect!")
    end

    it "sets the ui style" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:ui_style][:type]).to eq("horizontal")
    end

    it "sets the option feedbacks" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:metadata][:distractor_rationale_response_level][0])
        .to eq("Paris is the capital of France")
      expect(question.to_learnosity[:data][:metadata][:distractor_rationale_response_level][1])
        .to eq("Versailles is not the capital of France")
      expect(question.to_learnosity[:data][:metadata][:distractor_rationale_response_level][2])
        .to eq("Bordeaux is not the capital of France")
    end

    it "sets the shuffle options" do
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:shuffle_options]).to be_truthy
    end

    it "sets scoring type to exact match" do
      row["scoring type"] = "Exact Match"
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:validation][:scoring_type]).to eq("exactMatch")
    end

    it "sets scoring type to partial match" do
      row["scoring type"] = "Partial Match"
      question = described_class.new(row)
      expect(question.to_learnosity[:data][:validation][:scoring_type]).to eq("partialMatch")
    end

    context "when multiple response question" do
      let(:template) { "Multiple response" }
      let(:correct_answer) { "A;C" }

      it "sets the multiple responses" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:multiple_responses]).to be_truthy
      end

      it "sets the correct answer" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:validation][:valid_response][:value]).to eq(%w[0 2])
      end
    end

    context "when block layout question" do
      let(:template) { "Block layout" }

      it "sets the multiple responses" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:multiple_responses]).to be_falsey
      end

      it "sets the ui style" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:ui_style][:type]).to eq("block")
      end
    end

    context "when block layout multiple response question" do
      let(:template) { "Block layout multiple response" }
      let(:correct_answer) { "A;C" }

      it "sets the multiple responses" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:multiple_responses]).to be_truthy
      end

      it "sets the correct answer" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:validation][:valid_response][:value]).to eq(%w[0 2])
      end

      it "sets the ui style" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:ui_style][:type]).to eq("block")
      end
    end

    context "when choice matrix question" do
      let(:template) { "choice matrix" }
      let(:correct_answer) { "A;C" }

      it "sets the multiple responses" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:multiple_responses]).to be_truthy
      end

      it "sets the correct answer" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:validation][:valid_response][:value]).to eq(%w[0 2])
      end

      it "sets the ui style" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:ui_style][:type]).to eq("table")
      end
    end

    context "when choice matrix inline question" do
      let(:template) { "choice matrix inline" }
      let(:correct_answer) { "A;C" }

      it "sets the multiple responses" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:multiple_responses]).to be_truthy
      end

      it "sets the correct answer" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:validation][:valid_response][:value]).to eq(%w[0 2])
      end

      it "sets the ui style" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:ui_style][:type]).to eq("inline")
      end
    end

    context "when choice matrix labels" do
      let(:template) { "choice matrix labels" }
      let(:correct_answer) { "A;C" }

      it "sets the multiple responses" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:multiple_responses]).to be_truthy
      end

      it "sets the correct answer" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:validation][:valid_response][:value]).to eq(%w[0 2])
      end

      it "sets the ui style" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:ui_style][:type]).to eq("table")
        expect(question.to_learnosity[:data][:ui_style][:stem_numeration]).to eq("upper-alpha")
      end
    end

    context "when standard template" do
      let(:template) { "Standard" }

      it "sets the multiple responses" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:multiple_responses]).to be_falsey
      end

      it "sets the ui style" do
        question = described_class.new(row)
        expect(question.to_learnosity[:data][:ui_style][:type]).to eq("horizontal")
      end
    end
  end
end
