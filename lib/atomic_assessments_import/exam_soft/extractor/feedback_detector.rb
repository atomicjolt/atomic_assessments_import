# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class FeedbackDetector
        TILDE_PATTERN = /~\s*(.+)/m
        LABEL_PATTERN = /\A\s*(?:Explanation|Rationale):\s*(.+)/im
        OPTION_PATTERN = /\A\s*\*?[a-oA-O]\s*[.)]/

        def initialize(nodes)
          @nodes = nodes
        end

        def detect
          feedback_parts = []
          collecting = false

          @nodes.each do |node|
            text = node.text.strip

            if collecting
              # Stop collecting if we hit an option line
              break if text.match?(OPTION_PATTERN)
              feedback_parts << text unless text.empty?
              next
            end

            match = text.match(TILDE_PATTERN)
            if match
              first_part = match[1].strip
              feedback_parts << first_part unless first_part.empty?
              collecting = true
            end
          end

          return feedback_parts.join(" ").gsub(/\s+/, " ").strip unless feedback_parts.empty?

          @nodes.each do |node|
            text = node.text.strip
            match = text.match(LABEL_PATTERN)
            return match[1].gsub(/\s+/, " ").strip if match
          end

          nil
        end
      end
    end
  end
end
