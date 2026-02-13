# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class FillInTheBlank < Question
      def question_type
        "clozetext"
      end

      def question_data
        answers = (@row["correct answer"] || "").split(";").map(&:strip)
        super.merge(
          validation: {
            valid_response: {
              score: points,
              value: answers,
            },
          }
        )
      end
    end
  end
end
