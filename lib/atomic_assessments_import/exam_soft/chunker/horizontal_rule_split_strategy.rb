# frozen_string_literal: true

require_relative "strategy"

module AtomicAssessmentsImport
  module ExamSoft
    module Chunker
      class HorizontalRuleSplitStrategy < Strategy
        def split(doc)
          @header_nodes = []
          segments = []
          current_segment = []

          doc.children.each do |node|
            text = node.text.strip

            if node.name.match?(/^hr$/i)
              segments << current_segment unless current_segment.empty?
              current_segment = []
              next
            end

            next if text.empty? && !node.name.match?(/^(img|table)$/i)

            current_segment << node
          end

          segments << current_segment unless current_segment.empty?

          @header_nodes = segments.shift if segments.length >= 3

          segments.length >= 2 ? segments : []
        end
      end
    end
  end
end
