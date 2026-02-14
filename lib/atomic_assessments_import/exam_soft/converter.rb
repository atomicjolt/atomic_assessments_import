# frozen_string_literal: true

require "pandoc-ruby"
require "nokogiri"
require "active_support/core_ext/digest/uuid"

require_relative "../questions/question"
require_relative "../questions/multiple_choice"
require_relative "../questions/essay"
require_relative "../questions/short_answer"
require_relative "../questions/fill_in_the_blank"
require_relative "../questions/matching"
require_relative "../questions/ordering"
require_relative "../utils"
require_relative "chunker"
require_relative "extractor"

module AtomicAssessmentsImport
  module ExamSoft
    class Converter
      def initialize(file)
        @file = file
      end

      def convert
        html = normalize_to_html
        doc = Nokogiri::HTML.fragment(html)

        # Chunk the document
        chunk_result = Chunker.chunk(doc)
        all_warnings = chunk_result[:warnings].dup

        # Log header info if present
        unless chunk_result[:header_nodes].empty?
          header_text = chunk_result[:header_nodes].map { |n| n.text.strip }.join(" ")
          all_warnings << "Exam header detected: #{header_text}" unless header_text.empty?
        end

        items = []
        questions = []

        chunk_result[:chunks].each_with_index do |chunk_nodes, index|
          # Extract fields from this chunk
          extraction = Extractor.extract(chunk_nodes)
          all_warnings.concat(extraction[:warnings].map { |w| "Question #{index + 1}: #{w}" })

          row = extraction[:row]
          status = extraction[:status]

          # Skip completely unparseable chunks
          if row["question text"].nil? && row["option a"].nil?
            all_warnings << "Question #{index + 1}: Skipped — no usable content found"
            next
          end

          begin
            item, question_widgets = convert_row(row, status)
            items << item
            questions += question_widgets
          rescue StandardError => e
            title = row["title"] || "Question #{index + 1}"
            all_warnings << "#{title}: #{e.message}, imported as draft"
            begin
              item, question_widgets = convert_row_minimal(row)
              items << item
              questions += question_widgets
            rescue StandardError
              all_warnings << "#{title}: Could not import even minimally, skipped"
            end
          end
        end

        {
          activities: [],
          items: items,
          questions: questions,
          features: [],
          errors: all_warnings,
        }
      end

      private

      def normalize_to_html
        if @file.is_a?(String)
          PandocRuby.new([@file], from: @file.split(".").last).to_html
        else
          source_type = @file.path.split(".").last.match(/^[a-zA-Z]+/)[0]
          PandocRuby.new(@file.read, from: source_type).to_html
        end
      end

      def categories_to_tags(categories)
        tags = {}
        (categories || []).each do |cat|
          if cat.include?("/")
            key, value = cat.split("/", 2).map(&:strip)
            tags[key.to_sym] ||= []
            tags[key.to_sym] << value
          else
            tags[cat.to_sym] ||= []
          end
        end
        tags
      end

      def convert_row(row, status = "published")
        source = "<p>ExamSoft Import on #{Time.now.strftime('%Y-%m-%d')}</p>\n"
        if row["question id"].present?
          source += "<p>External id: #{row['question id']}</p>\n"
        end

        question = Questions::Question.load(row)
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
        [item, [question.to_learnosity]]
      end

      def convert_row_minimal(row)
        reference = SecureRandom.uuid
        item = {
          reference: reference,
          title: row["title"] || "",
          status: "draft",
          tags: {},
          metadata: {
            import_date: Time.now.iso8601,
            import_type: "examsoft",
          },
          source: "<p>ExamSoft Import on #{Time.now.strftime('%Y-%m-%d')}</p>\n",
          description: row["question text"] || "",
          questions: [],
          features: [],
          definition: { widgets: [] },
        }
        [item, []]
      end
    end
  end
end
