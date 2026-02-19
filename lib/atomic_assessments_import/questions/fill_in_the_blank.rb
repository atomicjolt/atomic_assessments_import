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
          stimulus: "Fill in the blank(s):",
          template: build_stimulus(answers), # Note: ExamSoft doesn't use a template like Learnosity
          validation: {
            valid_response: {
              score: points,
              value: answers,
            },
          }
        )
      end

      private

      def build_stimulus(answers)
        text = @row["question text"] || ""
        return text if text.include?("{{response}}")

        if text.match?(/__\d+__/)
          text.gsub(/__\d+__/, "{{response}}")
        else
          "#{text} #{Array.new(answers.size, "{{response}}").join(" ")}"
        end
      end
    end
  end
end
