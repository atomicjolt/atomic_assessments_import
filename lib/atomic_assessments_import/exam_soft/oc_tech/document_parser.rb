# frozen_string_literal: true

require "nokogiri"

module AtomicAssessmentsImport
  module ExamSoft
    module OcTech
      module DocumentParser
        STATS_LINE_MARKER = /Total Questions:/i

        # Split a normalized pandoc HTML fragment into an exam header and
        # per-question node blocks. A paragraph starts question N only when
        # its text begins with "N." AND N continues the ascending sequence —
        # this prevents false splits on stem lines that start with a number.
        def self.parse(doc)
          header_nodes = []
          blocks = []
          current = nil
          expected = 1
          warnings = []

          doc.children.each do |node|
            next if node.text? && node.text.strip.empty?

            if question_start?(node, expected)
              blocks << current if current
              current = [node]
              expected += 1
            elsif current
              current << node
            else
              header_nodes << node
            end
          end
          blocks << current if current

          warnings << "No numbered questions found — document may not be an OC Tech exam printout" if blocks.empty?

          {
            title: extract_title(header_nodes),
            declared_counts: extract_declared_counts(header_nodes),
            blocks: blocks,
            warnings: warnings,
          }
        end

        def self.question_start?(node, expected)
          node.text.strip.match?(/\A#{expected}\.(\s|\z)/)
        end

        def self.extract_title(header_nodes)
          first = header_nodes.map { |n| n.text.strip }.find(&:present?)
          first.presence
        end

        def self.extract_declared_counts(header_nodes)
          stats = header_nodes.map { |n| n.text.strip }.find { |t| t.match?(STATS_LINE_MARKER) }
          return {} unless stats

          stats.split("|").each_with_object({}) do |segment, counts|
            name, value = segment.split(":", 2).map(&:strip)
            counts[name] = Integer(value) if name.present? && value&.match?(/\A\d+\z/)
          end
        end
      end
    end
  end
end
