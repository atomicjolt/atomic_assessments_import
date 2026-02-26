# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class CorrectAnswerDetector
        ANSWER_LABEL_PATTERN = /\AAnswer:\s*(.+)/i

        def initialize(nodes, options)
          @nodes = nodes
          @options = options
        end

        def detect
          # First: check options for correct: true markers
          from_options = @options.select { |opt| opt[:correct] }.map { |opt| opt[:letter] }
          return from_options unless from_options.empty?

          # Second: scan nodes for "Answer:" label
          @nodes.each do |node|
            text = node.text.strip
            match = text.match(ANSWER_LABEL_PATTERN)
            next unless match

            answer_text = match[1].strip
            # Parse comma/space-separated letters
            letters = answer_text.split(/[\s,;]+/).map(&:strip).reject(&:empty?).map(&:downcase)
            return letters unless letters.empty?
          end

          []
        end
      end
    end
  end
end
