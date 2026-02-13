# frozen_string_literal: true

require_relative "exam_soft/converter"
require_relative "exam_soft/chunker/strategy"
require_relative "exam_soft/chunker/metadata_marker_strategy"
require_relative "exam_soft/chunker/numbered_question_strategy"
require_relative "exam_soft/chunker/heading_split_strategy"
require_relative "exam_soft/chunker/horizontal_rule_split_strategy"
require_relative "exam_soft/extractor/question_stem_detector"
require_relative "exam_soft/extractor/options_detector"
require_relative "exam_soft/extractor/correct_answer_detector"

module AtomicAssessmentsImport
  module ExamSoft
  end
end
