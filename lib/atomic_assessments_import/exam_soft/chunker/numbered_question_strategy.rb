# frozen_string_literal: true

require_relative "strategy"

module AtomicAssessmentsImport
  module ExamSoft
    module Chunker
      class NumberedQuestionStrategy < Strategy
        # Matches "1)" or "1." or "12)" etc. at start of text, but NOT single letters like "a)" because those are used for options, not question numbering
        NUMBERED_PATTERN = /\A\s*(\d+)\s*[.)]/

        def split(doc)
          @header_nodes = []
          chunks = []
          current_chunk = []
          found_first = false

          doc.children.each do |node|
            text = node.text.strip
            next if text.empty? && !node.name.match?(/^(img|table|hr)$/i)

            if text.match?(NUMBERED_PATTERN)
              found_first = true
              chunks << current_chunk unless current_chunk.empty?
              current_chunk = [node]
            elsif found_first
              current_chunk << node
            else
              @header_nodes << node
            end
          end

          chunks << current_chunk unless current_chunk.empty?
          found_first ? chunks : []
        end
      end
    end
  end
end
