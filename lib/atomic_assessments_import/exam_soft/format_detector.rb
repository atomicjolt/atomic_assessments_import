# frozen_string_literal: true

require "nokogiri"
require_relative "oc_tech"

module AtomicAssessmentsImport
  module ExamSoft
    # Ordered format probes for the unified ExamSoft converter. Each entry
    # pairs a detection lambda (run against the normalized HTML fragment)
    # with the pipeline module that parses that format. No probe matching
    # means the classic ExamSoft pipeline (the fallback by design — see
    # docs/superpowers/specs/2026-07-27-examsoft-unified-converter-design.md).
    #
    # Adding a future format: write a pipeline module honoring
    # `convert_document(doc)` (see ClassicPipeline/OcTech), add a probe
    # lambda, append a row here, and pin the new signature against the
    # existing ones in format_detector_spec.
    module FormatDetector
      OC_TECH_STATS_RE = /\|\s*Total Questions:\s*\d+/i
      OC_TECH_QUESTION_META_RE = /\AQuestion ID:\s*\d+\s*\|.*Point Value:/i
      FIRST_QUESTION_RE = /\A1\.(\s|\z)/

      FORMATS = [
        {
          name: :oc_tech,
          pipeline: OcTech,
          detect: lambda do |doc|
            lines = doc.children.map { |node| node.text.strip }
            first_question = lines.index { |t| t.match?(FIRST_QUESTION_RE) } || lines.length
            lines.first(first_question).any? { |t| t.match?(OC_TECH_STATS_RE) } ||
              lines.any? { |t| t.match?(OC_TECH_QUESTION_META_RE) }
          end,
        },
      ].freeze

      def self.detect(doc)
        FORMATS.find { |format| format[:detect].call(doc) }
      end
    end
  end
end
