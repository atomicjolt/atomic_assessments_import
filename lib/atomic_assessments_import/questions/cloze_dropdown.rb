# frozen_string_literal: true

require_relative "question"

module AtomicAssessmentsImport
  module Questions
    class ClozeDropdown < Question
      CHOICE_OF_PATTERN = /\AChoice of:\s*(.+)/i

      def question_type
        "clozedropdown"
      end

      def question_data
        parsed = parse_dropdown_options
        super.merge(
          stimulus: "",
          template: build_template(parsed.size),
          possible_responses: parsed.map { |p| p[:choices] },
          validation: {
            scoring_type: scoring_type,
            valid_response: {
              score: points,
              value: parsed.map { |p| p[:correct] },
            },
          }
        )
      end

      private

      def parse_dropdown_options
        ("a".."o").each_with_object([]) do |letter, acc|
          option = @row["option #{letter}"]
          break acc unless option

          m = option.match(CHOICE_OF_PATTERN)
          next unless m

          parts = m[1].split("|").map(&:strip)
          correct_index = parts.pop.to_i - 1
          acc << { choices: parts, correct: parts[correct_index] }
        end
      end

      def build_template(blank_count)
        text = @row["question text"] || ""
        return text if text.include?("{{response}}")

        if text.match?(/__\d+__/)
          text.gsub(/__\d+__/, "{{response}}")
        elsif text.match?(/_____/)
          text.gsub(/_____/, "{{response}}")
        elsif text.match?(/\[[A-Za-z0-9]\]/)
          text.gsub(/\[[A-Za-z0-9]\]/, "{{response}}")
        else
          "#{text} #{Array.new(blank_count, "{{response}}").join(" ")}"
        end
      end
    end
  end
end
