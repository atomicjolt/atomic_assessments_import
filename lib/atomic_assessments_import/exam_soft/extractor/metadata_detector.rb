# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class MetadataDetector
        FOLDER_PATTERN = /Folder:\s*(.+?)(?=\s*(?:Title:|Category:|\d+[.)]))/i
        TITLE_PATTERN = /Title:\s*(.+?)(?=\s*(?:Category:|\d+[.)]))/i
        CATEGORY_PATTERN = /Category:\s*(.+?)(?=\s*\d+[.)]|\z)/i
        TYPE_PATTERN = /Type:\s*(\S+)/i

        def initialize(nodes)
          @nodes = nodes
        end

        def detect
          full_text = @nodes.map { |n| n.text.strip }.join(" ")
          result = {}

          type_match = full_text.match(TYPE_PATTERN)
          result[:type] = type_match[1].strip.downcase if type_match

          folder_match = full_text.match(FOLDER_PATTERN)
          result[:folder] = folder_match[1].strip if folder_match

          title_match = full_text.match(TITLE_PATTERN)
          result[:title] = title_match[1].strip if title_match

          category_match = full_text.match(CATEGORY_PATTERN)
          result[:categories] = category_match[1].split(",").map(&:strip) if category_match

          result
        end
      end
    end
  end
end
