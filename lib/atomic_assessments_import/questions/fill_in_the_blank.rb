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
          stimulus: "", # Note: ExamSoft doesn't use a template like Learnosity, so we put the full question text in the template and leave the stimulus blank
          template: build_stimulus(answers), 
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
