# frozen_string_literal: true

require_relative "oc_tech/document_parser"
require_relative "oc_tech/question_parser"
require_relative "oc_tech/item_builder"
require_relative "oc_tech/converter"

module AtomicAssessmentsImport
  module ExamSoft
    module OcTech
      # Pipeline entry point for the unified ExamSoft converter (see
      # FormatDetector). Parses an already-normalized fragment whose img srcs
      # were already rewritten to ___EXPORT_ROOT___/assets/… by the caller.
      def self.convert_document(doc)
        parsed_doc = DocumentParser.parse(doc)
        errors = parsed_doc[:warnings].map { |w| build_error(w) }

        items = []
        questions = []
        parsed_doc[:blocks].each_with_index do |nodes, index|
          parsed = QuestionParser.parse(nodes, index + 1)
          parsed.warnings.each { |w| errors << build_error(w) }
          next if parsed.type == :unknown

          built = ItemBuilder.build(parsed, exam_title: parsed_doc[:title].to_s)
          built[:warnings].each { |w| errors << build_error(w, question_type: parsed.type.to_s) }
          items << built[:item]
          questions.concat(built[:questions])
        end

        declared = parsed_doc[:declared_counts]["Total Questions"]
        if declared && declared != parsed_doc[:blocks].length
          errors << build_error("header declares #{declared} questions, parsed #{parsed_doc[:blocks].length}")
        end

        {
          title: parsed_doc[:title],
          items: items,
          questions: questions,
          features: [],
          errors: errors,
        }
      end

      def self.build_error(message, error_type: "warning", question_type: nil)
        {
          error_type: error_type,
          question_type: question_type,
          message: message,
          qti_item_id: nil,
          index: nil,
        }
      end
    end
  end
end
