# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class OptionsDetector
        OPTION_PATTERN = /\A\s*(\*?)([a-oA-O])\s*[.)]\s*(.+)/m

        def initialize(nodes)
          @nodes = nodes
        end

        def detect
          options = []

          @nodes.each do |node|
            text = node.text.strip
            match = text.match(OPTION_PATTERN)
            next unless match

            marker = match[1]
            letter = match[2].downcase
            option_text = match[3].strip

            correct = marker == "*" || bold_node?(node)

            options << { text: option_text, letter: letter, correct: correct }
          end

          options
        end

        private

        def bold_node?(node)
          # Check if the node's first significant child is a <strong> or <b> element
          node.css("strong, b").any? do |bold_el|
            bold_el.text.strip == node.text.strip
          end
        end
      end
    end
  end
end
