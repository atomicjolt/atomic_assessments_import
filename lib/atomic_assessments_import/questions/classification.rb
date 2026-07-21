# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class Classification < Question
      LETTERS = ("a".."o").to_a.freeze

      def question_type
        "classification"
      end

      def question_data
        raise "Missing correct answer" if correct_indices.empty?

        super.merge(
          possible_responses: @row["possible responses"],
          ui_style: {
            column_titles: ["Correct Answers"],
            row_titles: [],
            column_count: 1,
            row_count: 1,
          },
          max_response_per_cell: @row["possible responses"].length,
          validation: {
            scoring_type: scoring_type,
            valid_response: {
              score: points,
              value: [correct_indices],
            },
            penalty: 1,
            rounding: "none",
          }
        )
      end

      def correct_indices
        (@row["correct answer"] || "").split(";").map(&:strip).map(&:downcase)
          .filter_map { |letter| LETTERS.index(letter) }
      end
    end
  end
end
