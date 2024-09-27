require 'csv'

require_relative "questions/question"
require_relative "questions/multiple_choice"

module AtomicAssessmentsImports
  module CSV
    class Converter
      def initialize(file)
        @file = file
      end

      def convert
        items = []
        widgets = []

        ::CSV.foreach(@file, headers: true) do |row|
          sanitized = row.map { |k, v| [k.strip, v&.strip] }
          item, csv_widget = convert_row(sanitized)

          items << item
          widgets += csv_widget
        end

        {
          activities: [],
          items:,
          questions: widgets,
        }
      end

      private

      def convert_row(row)
        question = Questions::MultipleChoice.new(row)
        puts question.to_learnosity

        item = {
          reference: question.question_reference + "-item",
          title: question.id,
          status: "published",
          tags: question.tags,
          max_score: 1,
          metadata: { question_id: question.id },
          questions: [
            {
              reference: question.question_reference,
              type: question.type,
            }
          ],
          definition: {
            widgets: [
              {
                reference: question.question_reference,
                widget_type: "response",
              }
            ]
          },
        }

        [item, [question.to_learnosity]]
      end
    end
  end
end
