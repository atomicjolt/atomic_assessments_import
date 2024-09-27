require_relative 'question'

module AtomicAssessmentsImports
  module CSV
    module Questions
      class MultipleChoice < Question

        def type
          "mcq"
        end

        def to_learnosity
          {
            type: "mcq",
            widget_type: "response",
            reference: question_reference,
            data: {
              type: "mcq",
              multiple_responses: correct_responses.size > 1,
              stimulus: text,
              metadata: {
                general_feedback: general_feedback,
              },
              options: options,
              validation: {
                scoring_type: "partialMatchV2",
                valid_response: { score: 1, value: correct_responses },
              },
            }
          }
        end

        def options
          @options ||= extract_options()
        end

        def correct_responses
          @correct_responses ||= extract_correct_responses()
        end

        private

        def extract_options
          @row.filter_map do |key, value|
            if key.downcase.start_with?("option")
              option_value = key.gsub(/option/i, "").strip
              { label: value, value: option_value }
            end
          end
        end

        def extract_correct_responses
          get("correct answer").split(",").map(&:strip)
        end
      end
    end
  end
end
