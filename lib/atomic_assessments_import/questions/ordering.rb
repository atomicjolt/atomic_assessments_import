# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class Ordering < Question
      INDEXES = ("a".."o").to_a.freeze

      def question_type
        "orderlist"
      end

      def question_data
        items = []
        INDEXES.each do |letter|
          option = @row["option #{letter}"]
          break unless option
          items << option
        end

        order = (@row["correct answer"] || "").split(";").map(&:strip).map(&:downcase)
        valid_values = order.filter_map { |letter| INDEXES.find_index(letter)&.to_s }

        super.merge(
          list: items,
          validation: {
            valid_response: {
              score: points,
              value: valid_values,
            },
          }
        )
      end
    end
  end
end
