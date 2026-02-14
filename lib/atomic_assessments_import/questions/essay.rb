# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class Essay < Question
      def question_type
        "longanswer"
      end

      def question_data
        data = super
        word_limit = @row["word_limit"]&.to_i
        data[:max_length] = word_limit if word_limit&.positive?
        data
      end
    end
  end
end
