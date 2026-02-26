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
        normalize_html_structure(doc)

        # Chunk the document
        chunk_result = Chunker.chunk(doc)
        all_warnings = chunk_result[:warnings].map { |w| build_warning(w) }

        if chunk_result[:chunks].length == 1
          all_warnings << build_warning("Only 1 chunk detected — document may not be in a recognized format")
        end

        # Log header info if present
        unless chunk_result[:header_nodes].empty?
          header_text = chunk_result[:header_nodes].map { |n| n.text.strip }.join(" ")
          all_warnings << build_warning("Exam header detected: #{header_text}") unless header_text.empty?
        end

        items = []
        questions = []

        chunk_result[:chunks].each_with_index do |chunk_nodes, index|
          # Extract fields from this chunk
          extraction = Extractor.extract(chunk_nodes)
          extraction[:warnings].each do |w|
            all_warnings << build_warning("Question #{index + 1}: #{w}", index: index, question_type: extraction[:row]["question type"])
          end

          row = extraction[:row]
          status = extraction[:status]

          # Skip completely unparseable chunks
          if row["question text"].nil? && row["option a"].nil?
            all_warnings << build_warning("Question #{index + 1}: Skipped — no usable content found", index: index)
            next
          end

          next unless status == "published"

          begin
            item, question_widgets = convert_row(row, "published")
            items << item
            questions += question_widgets
          rescue StandardError => e
            title = row["title"] || "Question #{index + 1}"
            all_warnings << build_warning("#{title}: #{e.message}", index: index, question_type: row["question type"])
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

      def build_warning(message, index: nil, question_type: nil)
        {
          error_type: "warning",
          question_type: question_type,
          message: message,
          qti_item_id: nil,
          index: index,
        }
      end

      def normalize_html_structure(doc)
        doc.css("p").each do |p_node|
          br_children = p_node.css("br")
          next if br_children.empty?

          # Split the <p> at each <br> into separate <p> elements
          segments = []
          current_segment = []

          p_node.children.each do |child|
            if child.name == "br"
              segments << current_segment unless current_segment.empty?
              current_segment = []
            else
              current_segment << child
            end
          end
          segments << current_segment unless current_segment.empty?

          next if segments.length <= 1

          # Replace original <p> with multiple <p> elements
          segments.reverse_each do |segment|
            new_p = Nokogiri::XML::Node.new("p", doc)
            segment.each { |child| new_p.add_child(child.clone) }
            p_node.add_next_sibling(new_p)
          end
          p_node.remove
        end
      end

      def normalize_to_html
        # Note: Pandoc Ruby takes either a file path or a string of content, but not a File object directly, so we have to handle both cases here
        if @file.is_a?(String)
          # File path as string
          PandocRuby.new([@file], from: @file.split(".").last).to_html
        elsif @file.respond_to?(:path) && @file.respond_to?(:read)
          # File-like object (File, Tempfile, etc.)
          source_type = @file.path.split(".").last.match(/^[a-zA-Z]+/)[0]
          PandocRuby.new(@file.read, from: source_type).to_html
        else
          raise ArgumentError, "Expected a file path (String) or file-like object, got #{@file.class}"
        end
      end

      def categories_to_tags(categories)
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

      def convert_row(row, status = "published")
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
