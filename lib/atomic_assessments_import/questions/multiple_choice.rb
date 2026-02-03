# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  # module CSV
    module Questions
      class MultipleChoice < Question
        QUESTION_INDEXES = ("a".."o").to_a.freeze

        def question_type
          "mcq"
        end

        def question_data
          raise "Missing correct answer" if correct_responses.empty?
          raise "Missing options" if options.empty?

          super.deep_merge(
            {
              multiple_responses: multiple_responses,
              options: options,
              validation: {
                scoring_type: scoring_type,
                valid_response: {
                  score: points,
                  value: correct_responses,
                },
                rounding: "none",
                penalty: 1,
              },
              shuffle_options: Utils.parse_boolean(@row["shuffle options"], default: false),
              ui_style: ui_style,
            }
          )
        end

        def metadata
          super.merge(
            {
              distractor_rationale_response_level: distractor_rationale_response_level,
            }
          )
        end

        def options
          QUESTION_INDEXES.filter_map.with_index do |value, cnt|
            key = "option #{value}"
            if @row[key].present?
              {
                label: @row[key],
                value: cnt.to_s,
              }
            end
          end
        end

        def correct_responses
          correct = @row["correct answer"]&.split(";")&.map(&:strip)&.map(&:downcase) || []

          correct.filter_map do |value|
            QUESTION_INDEXES.find_index(value).to_s
          end
        end

        def distractor_rationale_response_level
          QUESTION_INDEXES.map do |value|
            key = "option #{value} feedback"
            @row[key].presence || ""
          end.reverse.drop_while(&:blank?).reverse
        end

        def multiple_responses
          case @row["template"]&.downcase
          when "multiple response", "block layout multiple response", "choice matrix",
            "choice matrix inline", "choice matrix labels"
            true
          else
            false
          end
        end

        def ui_style
          case @row["template"]&.downcase
          when "multiple response"
            { type: "horizontal" }
          when "block layout", "block layout multiple response"
            { choice_label: "upper-alpha", type: "block" }
          when "choice matrix"
            { horizontal_lines: false, type: "table" }
          when "choice matrix inline"
            { horizontal_lines: false, type: "inline" }
          when "choice matrix labels"
            { stem_numeration: "upper-alpha", horizontal_lines: false, type: "table" }
          when nil, "", "multiple choice", "standard"
            { type: "horizontal" }
          else
            raise "Unknown template: #{@row["template"]}"
          end
        end
      end
    end
  # end
end
