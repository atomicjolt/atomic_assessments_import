# frozen_string_literal: true

module AtomicAssessmentsImport
  module Questions
    class Question
      def initialize(row)
        @row = row
        # @question_reference = Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "#{@item_url}/question")
        @reference = SecureRandom.uuid
      end

      def self.load(row)
        case row["question type"]
        when nil, "", /multiple choice/i, /mcq/i, /ma/i # TODO - verify ma is fine here
          MultipleChoice.new(row)
        else
          raise "Unknown question type #{row['question type']}"
        end
      end

      attr_reader :reference

      def question_type
        raise NotImplementedError
      end

      def question_data
        {
          stimulus: @row["question text"],
          type: question_type,
          metadata: metadata,
          **{
            stimulus_review: @row["stimulus review"],
            instructor_stimulus: @row["instructor stimulus"],
          }.compact,
        }
      end

      def metadata
        {
          distractor_rationale: @row["distractor rationale"],
          sample_answer: @row["sample answer"],
          acknowledgements: @row["acknowledgements"],
          general_feedback: @row["general feedback"],
          correct_feedback: @row["correct feedback"],
          partially_correct_feedback: @row["partially correct feedback"],
          incorrect_feedback: @row["incorrect feedback"],
        }.compact
      end

      def scoring_type
        case @row["scoring type"]
        when nil, "", /Partial Match Per Response/i
          "partialMatchV2"
        when /Partial Match/i
          "partialMatch"
        when /Exact Match/i
          "exactMatch"
        else
          raise "Unknown scoring type #{@row['scoring type']}"
        end
      end

      def points
        if @row["points"].blank?
          1
        else
          Float(@row["points"])
        end
      rescue ArgumentError
        1
      end

      def to_learnosity
        {
          type: question_type,
          widget_type: "response",
          reference: @reference,
          data: question_data,
        }
      end
    end
  end
end
