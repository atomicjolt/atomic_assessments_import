# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class Matching < Question
      INDEXES = ("a".."o").to_a.freeze

      def question_type
        "association"
      end

      def question_data
        stimulus_list = []
        possible_responses = []
        valid_values = []

        INDEXES.each do |letter|
          option = @row["option #{letter}"]
          match_val = @row["match #{letter}"]
          break unless option

          stimulus_list << option
          possible_responses << match_val if match_val
          valid_values << match_val if match_val
        end

        super.merge(
          stimulus_list: stimulus_list,
          possible_responses: possible_responses,
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
