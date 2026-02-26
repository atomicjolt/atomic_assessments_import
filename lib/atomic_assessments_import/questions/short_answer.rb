# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class ShortAnswer < Question
      def question_type
        "shorttext"
      end

      def question_data
        super.merge(
          validation: {
            valid_response: {
              score: points,
              value: @row["correct answer"] || "",
            },
          }
        )
      end
    end
  end
end
