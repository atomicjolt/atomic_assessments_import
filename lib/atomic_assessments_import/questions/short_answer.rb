# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class ShortAnswer < Question
      def question_type
        "shorttext"
      end

      def question_data
        validation = {
          scoring_type: "exactMatch",
          valid_response: {
            score: points,
            value: @row["correct answer"] || "",
          },
        }
        alternates = Array(@row["alternate answers"]).reject(&:blank?)
        if alternates.any?
          validation[:alt_responses] = alternates.map { |value| { score: points, value: value } }
        end
        super.merge(validation: validation)
      end
    end
  end
end
