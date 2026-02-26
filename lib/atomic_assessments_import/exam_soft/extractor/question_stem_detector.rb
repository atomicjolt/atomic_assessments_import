# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class QuestionStemDetector
        OPTION_PATTERN = /\A\s*\*?[a-oA-O]\s*[.)]/

        def initialize(nodes)
          @nodes = nodes
        end

        def detect
          stem_node = @nodes.find do |node|
            text = node.text.strip
            next if text.empty?
            next if text.match?(OPTION_PATTERN)

            true
          end

          return nil unless stem_node

          text = stem_node.text.strip

          # Strip metadata prefixes and numbered prefix together
          # e.g. "Folder: Geo Title: Q1 Category: Test 1) What is the capital?"
          text = if text.match?(/\d+[.)]/m)
                   text.sub(/\A.*?(?<!\S)\d+[.)]\s*/m, "")
                 else
                   # Strip standalone metadata labels if present (Folder:, Title:, Category:, Type:)
                   text.sub(/\A\s*(?:(?:Folder|Title|Category|Type):\s*\S+\s*)*/, "")
                 end

          # Split on tilde and take the first part (remove explanation)
          text = text.split("~").first

          text = text&.gsub(/\s+/, " ")&.strip
          text.nil? || text.empty? ? nil : text
        end
      end
    end
  end
end
