# frozen_string_literal: true

require_relative "extractor/question_stem_detector"
require_relative "extractor/options_detector"
require_relative "extractor/correct_answer_detector"
require_relative "extractor/metadata_detector"
require_relative "extractor/feedback_detector"
require_relative "extractor/question_type_detector"

module AtomicAssessmentsImport
  module ExamSoft
    module Extractor
      SUPPORTED_TYPES = %w[mcq ma true_false essay short_answer fill_in_the_blank matching ordering].freeze
      OPTION_TYPES = %w[mcq ma true_false].freeze

      def self.extract(nodes)
        warnings = []

        # Run detectors
        options = OptionsDetector.new(nodes).detect
        has_options = !options.empty?

        metadata = MetadataDetector.new(nodes).detect
        question_type = QuestionTypeDetector.new(nodes, has_options: has_options).detect
        stem = QuestionStemDetector.new(nodes).detect
        feedback = FeedbackDetector.new(nodes).detect
        correct_answers = has_options ? CorrectAnswerDetector.new(nodes, options).detect : []

        # Determine status
        status = "published"

        unless SUPPORTED_TYPES.include?(question_type)
          warnings << "Unsupported question type '#{question_type}'"#, imported as draft"
          status = "draft"
        end

        if stem.nil?
          warnings << "No question text found"#, imported as draft"
          status = "draft"
        end

        if OPTION_TYPES.include?(question_type)
          if options.empty?
            warnings << "No options found for #{question_type} question"#, imported as draft"
            status = "draft"
          end
          if correct_answers.empty?
            warnings << "No correct answer found"#, imported as draft"
            status = "draft"
          end
        end

        # Build row_mock
        row = {
          "question id" => nil,
          "folder" => metadata[:folder],
          "title" => metadata[:title],
          "category" => metadata[:categories] || [],
          "import type" => nil,
          "description" => nil,
          "question text" => stem,
          "question type" => question_type,
          "stimulus review" => nil,
          "instructor stimulus" => nil,
          "correct answer" => correct_answers.join("; "),
          "scoring type" => nil,
          "points" => nil,
          "distractor rationale" => nil,
          "sample answer" => nil,
          "acknowledgements" => nil,
          "general feedback" => feedback,
          "correct feedback" => nil,
          "incorrect feedback" => nil,
          "shuffle options" => nil,
          "template" => "block layout",
        }

        # Add option keys
        options.each_with_index do |opt, index|
          letter = ("a".ord + index).chr
          row["option #{letter}"] = opt[:text]
        end

        # For FITB questions, options ARE the answers (no asterisk marking)
        if question_type == "fill_in_the_blank" && row["correct answer"].blank? && !options.empty?
          row["correct answer"] = options.map { |opt| opt[:text] }.join("; ")
        end

        {
          row: row,
          status: status,
          warnings: warnings,
        }
      end
    end
  end
end
