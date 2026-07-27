# frozen_string_literal: true

require "pandoc-ruby"
require "nokogiri"
require "active_support/core_ext/digest/uuid"

require_relative "../utils"
require_relative "classic_pipeline"
require_relative "html_normalizer"

module AtomicAssessmentsImport
  module ExamSoft
    class Converter
      def initialize(file)
        @file = file
      end

      def convert
        html = normalize_to_html
        doc = Nokogiri::HTML.fragment(html)
        HtmlNormalizer.normalize!(doc)

        result = ClassicPipeline.convert_document(doc)

        {
          activities: [],
          items: result[:items],
          questions: result[:questions],
          features: [],
          errors: result[:errors],
        }
      end

      private

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

    end
  end
end
