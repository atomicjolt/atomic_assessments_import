# frozen_string_literal: true

require "csv"
require "active_support/core_ext/digest/uuid"

require_relative "questions/question"
require_relative "questions/multiple_choice"
require_relative "utils"

module AtomicAssessmentsImport
  module CSV
    class Converter
      HEADERS = [
        "question id",
        "title",
        /tag: *[a-zA-Z0-9_].*/,
        "question text",
        "question type",
        "template",
        "correct answer",
        /option [a-o]/,
        /option [a-o] feedback/,
        "scoring type",
        "shuffle options",
        "points",
        "general feedback",
        "correct feedback",
        "partially correct feedback",
        "incorrect feedback",
        "distractor rationale",
        "stimulus review",
        "acknowledgements",
        "instructor stimulus",
        "sample answer",
        "description",
        "alignment url",
      ].freeze

      def initialize(file)
        @file = file
      end

      def convert
        items = []
        questions = []

        ::CSV.foreach(
          @file,
          headers: true,
          header_converters: lambda do |header|
            normalized = header.strip
            normalized =
              if (m = normalized.match(/^tag:(.+)$/i))
                "tag:#{m[1].strip}"
              else
                normalized.downcase
              end
            if !HEADERS.find { |h| h.is_a?(Regexp) ? h =~ normalized : h == normalized }
              raise "Unknown column: #{header}"
            end

            normalized
          end,
          converters: ->(data) { data&.strip }
        ).with_index(2) do |row, line|
          item, question_widgets = convert_row(row)

          items << item
          questions += question_widgets
        rescue StandardError => e
          raise e, "Error processing line #{line}: #{e.message}"
        end

        {
          activities: [],
          items:,
          questions:,
          features: [],
          errors: [],
        }
      end

      private

      def tags(row)
        tags = {}
        row.headers.each.with_index do |header, idx|
          if header&.start_with?("tag:")
            tag_name = header.gsub(/^tag:/, "").to_sym
            tags[tag_name] ||= []
            tags[tag_name] << row[idx] if row[idx].present?
          end
        end
        if alignment_urls(row).present?
          tags[:lrn_aligned] = alignment_urls(row).map do |url|
            Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, url)
          end
        end
        tags
      end

      def alignment_urls(row)
        if row.headers.include?("alignment url")
          row.headers.filter_map.with_index do |header, idx|
            row[idx] if header == "alignment url" && row[idx].present?
          end
        end.presence
      end

      def convert_row(row)
        source = "<p>CSV Import on #{Time.now.strftime('%Y-%m-%d')}</p>\n"
        if row["question id"].present?
          source += "<p>External id: #{row['question id']}</p>\n"
        end

        question = Questions::Question.load(row)
        item = {
          reference: SecureRandom.uuid,
          title: row["title"] || "",
          status: "published",
          tags: tags(row),
          metadata: {
            import_date: Time.now.iso8601,
            import_type: "csv",
            **{
              external_id: row["question id"],
              external_id_domain: row["question id"].present? ? "csv" : nil,
              alignment: alignment_urls(row),
            }.compact,
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
            ]
          },
        }
        [item, [question.to_learnosity]]
      end
    end
  end
end
