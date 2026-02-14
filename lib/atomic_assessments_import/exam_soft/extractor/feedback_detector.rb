# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class FeedbackDetector
        TILDE_PATTERN = /~\s*(.+)/m
        LABEL_PATTERN = /\A\s*(?:Explanation|Rationale):\s*(.+)/im

        def initialize(nodes)
          @nodes = nodes
        end

        def detect
          @nodes.each do |node|
            text = node.text.strip
            match = text.match(TILDE_PATTERN)
            if match
              feedback = match[1].gsub(/\s+/, " ").strip
              return feedback unless feedback.empty?
            end
          end

          @nodes.each do |node|
            text = node.text.strip
            match = text.match(LABEL_PATTERN)
            if match
              return match[1].gsub(/\s+/, " ").strip
            end
          end

          nil
        end
      end
    end
  end
end
