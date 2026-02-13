# frozen_string_literal: true

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      class QuestionTypeDetector
        TYPE_LABEL_PATTERN = /Type:\s*(.+?)(?=\s*(?:Folder:|Title:|Category:|\d+[.)]|\z))/i

        TYPE_MAP = {
          /\Amcq?\z/i => "mcq",
          /\Amultiple\s*choice\z/i => "mcq",
          /\Ama\z/i => "ma",
          /\Amultiple\s*(?:select|answer|response)\z/i => "ma",
          /\Atrue[\s\/]*false\z/i => "true_false",
          /\At\s*\/?\s*f\z/i => "true_false",
          /\Aessay\z/i => "essay",
          /\Along\s*answer\z/i => "essay",
          /\Ashort\s*answer\z/i => "short_answer",
          /\Afill[\s_-]*in[\s_-]*(?:the[\s_-]*)?blank\z/i => "fill_in_the_blank",
          /\Acloze\z/i => "fill_in_the_blank",
          /\Amatching\z/i => "matching",
          /\Aorder(?:ing)?\z/i => "ordering",
        }.freeze

        def initialize(nodes, has_options:)
          @nodes = nodes
          @has_options = has_options
        end

        def detect
          full_text = @nodes.map { |n| n.text.strip }.join(" ")
          match = full_text.match(TYPE_LABEL_PATTERN)

          if match
            type_text = match[1].strip
            TYPE_MAP.each do |pattern, type|
              return type if type_text.match?(pattern)
            end
            return type_text.downcase.gsub(/\s+/, "_")
          end

          @has_options ? "mcq" : "short_answer"
        end
      end
    end
  end
end
