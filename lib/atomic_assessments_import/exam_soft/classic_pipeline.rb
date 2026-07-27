# frozen_string_literal: true

require "nokogiri"

require_relative "../questions/question"
require_relative "../questions/multiple_choice"
require_relative "../questions/essay"
require_relative "../questions/short_answer"
require_relative "../questions/fill_in_the_blank"
require_relative "../questions/matching"
require_relative "../questions/ordering"
require_relative "chunker"
require_relative "extractor"

module AtomicAssessmentsImport
  module ExamSoft
    # Classic ExamSoft parsing (chunker + extractor strategy cascade),
    # extracted unchanged from ExamSoft::Converter. This is the fallback
    # pipeline when FormatDetector matches nothing.
    module ClassicPipeline
      def self.convert_document(doc)
        chunk_result = Chunker.chunk(doc)
        errors = chunk_result[:warnings].map { |w| build_warning(w) }

        if chunk_result[:chunks].length == 1
          errors << build_warning("Only 1 chunk detected — document may not be in a recognized format")
        end

        header_text = chunk_result[:header_nodes].map { |n| n.text.strip }.join(" ").strip

        items = []
        questions = []

        chunk_result[:chunks].each_with_index do |chunk_nodes, index|
          # Extract fields from this chunk
          extraction = Extractor.extract(chunk_nodes)
          extraction[:warnings].each do |w|
            errors << build_warning("Question #{index + 1}: #{w}", question_type: extraction[:row]["question type"])
          end

          row = extraction[:row]
          status = extraction[:status]

          # Skip completely unparseable chunks
          if row["question text"].nil? && row["option a"].nil?
            errors << build_warning("Question #{index + 1}: Skipped — no usable content found")
            next
          end

          next unless status == "published"

          begin
            item, question_widgets = convert_row(row, "published")
            items << item
            questions += question_widgets
          rescue StandardError => e
            title = row["title"] || "Question #{index + 1}"
            errors << build_warning("#{title}: #{e.message}", question_type: row["question type"])
          end
        end

        {
          title: header_text.presence,
          items: items,
          questions: questions,
          features: [],
          errors: errors,
        }
      end

      # index is intentionally omitted here — Converter#finalize_errors
      # assigns the final :index on every error/warning after all pipelines run.
      def self.build_warning(message, question_type: nil)
        {
          error_type: "warning",
          question_type: question_type,
          message: message,
          qti_item_id: nil,
          index: nil,
        }
      end

      def self.categories_to_tags(categories)
        tags = {}
        (categories || []).each do |cat|
          parts = cat.to_s.split("/")
          key = parts.shift&.strip
          value = parts.join("/").strip
          next if key.blank? || value.blank?

          key = key.delete(":")[0, 255]
          value = value[0, 255]
          next if key.blank? || value.blank?

          tags[key.to_sym] ||= []
          tags[key.to_sym] |= [value]
        end
        tags
      end

      def self.convert_row(row, status = "published")
        source = "<p>ExamSoft Import on #{Time.now.strftime('%Y-%m-%d')}</p>\n"
        source += "<p>External id: #{row['question id']}</p>\n" if row["question id"].present?

        question = Questions::Question.load(row)
        # ExamSoft has a dedicated Multiple Answer question type, but Learnosity does not, so we need to update the question type and UI style for those questions
        question_learnosity = question.to_learnosity
        if row["question type"] == "ma"
          question_learnosity[:data][:ui_style] = { choice_label: "upper-alpha", type: "block" }
          question_learnosity[:data][:multiple_responses] = true
        end

        item = {
          reference: SecureRandom.uuid,
          title: row["title"] || "",
          status: status,
          tags: categories_to_tags(row["category"]),
          metadata: {
            import_date: Time.now.iso8601,
            import_type: row["import_type"] || "examsoft",
          },
          source: source,
          description: row["description"] || "",
          questions: [
            {
              reference: question.reference,
              type: question.question_type,
            },
          ],
          features: [],
          definition: {
            widgets: [
              {
                reference: question.reference,
                widget_type: "response",
              },
            ],
          },
        }
        [item, [question_learnosity]]
      end
    end
  end
end
