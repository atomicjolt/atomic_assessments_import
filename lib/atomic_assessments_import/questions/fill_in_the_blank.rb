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
            scoring_type: scoring_type,
            valid_response: {
              score: points,
              value: answers
            },
          }
        )
      end

      private

      def build_stimulus(answers)
        text = @row["question text"] || ""
        return text if text.include?("{{response}}")

        # You can indicate the blank(s) in various ways:
        # Five underscores
        # Number enclosed by two underscores on each side
        # Number, uppercase letter, or lowercase letter enclosed by square brackets
        if text.match?(/__\d+__/)
          text.gsub(/__\d+__/, "{{response}}")
        elsif text.match?(/_____/)
          text.gsub(/_____/, "{{response}}")
        elsif text.match?(/\[[A-Za-z0-9]\]/)
          text.gsub(/\[[A-Za-z0-9]\]/, "{{response}}")
        else
          "#{text} #{Array.new(answers.size, "{{response}}").join(" ")}"
        end
      end
    end
  end
end
