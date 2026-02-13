# frozen_string_literal: true

require_relative "chunker/strategy"
require_relative "chunker/metadata_marker_strategy"
require_relative "chunker/numbered_question_strategy"
require_relative "chunker/heading_split_strategy"
require_relative "chunker/horizontal_rule_split_strategy"

module AtomicAssessmentsImport
  module ExamSoft
    module Chunker
      STRATEGIES = [
        MetadataMarkerStrategy,
        NumberedQuestionStrategy,
        HeadingSplitStrategy,
        HorizontalRuleSplitStrategy,
      ].freeze

      def self.chunk(doc)
        warnings = []

        STRATEGIES.each do |strategy_class|
          strategy = strategy_class.new
          chunks = strategy.split(doc)
          next if chunks.empty?

          return {
            chunks: chunks,
            header_nodes: strategy.header_nodes,
            warnings: warnings,
          }
        end

        # No strategy matched — return entire document as one chunk
        all_nodes = doc.children.reject { |n| n.text.strip.empty? && !n.name.match?(/^(img|table|hr)$/i) }
        warnings << "No chunking strategy matched. Treating entire document as a single question."

        {
          chunks: [all_nodes],
          header_nodes: [],
          warnings: warnings,
        }
      end
    end
  end
end
