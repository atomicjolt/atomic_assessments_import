# frozen_string_literal: true

require "nokogiri"

module AtomicAssessmentsImport
  module ExamSoft
    module OcTech
      ParsedQuestion = Struct.new(
        :number, :type, :stem_html, :options, :groups, :metadata, :answers, :warnings,
        keyword_init: true
      )

      module QuestionParser
        OPTION_RE = /\A([A-O])\.\s+(.+)\z/m
        ANSWER_RE = /\AAnswer(?:\s+Part\s+(\d+))?\s*:\s*(.*)\z/im
        GROUP_RE = /\A(.+?)\s*\((?:choose|select)\s+(\d+)\)\s*:?\z/i
        METADATA_KEYS = ["question id", "point value", "point biserial", "difficulty", "rationale", "categories"].freeze
        BLANK_MARKER = /_{3,}/

        def self.parse(nodes, number)
          state = {
            stem: [], options: [], groups: [], metadata: {}, answers: [], warnings: [],
            current_group: nil, seen_blank: false, indexed_answer_next: 1
          }

          nodes.each_with_index do |node, idx|
            node = strip_question_number(node, number) if idx.zero?
            next if node.nil? || node.text.strip.empty? && node.css("img, table").empty?

            classify_node(node, state)
          end

          build_question(number, state)
        end

        # Remove the leading "N." from the first text descendant of the block's
        # first node, preserving all other markup. Returns nil if nothing remains.
        def self.strip_question_number(node, number)
          text_node = node.xpath(".//text()").find { |t| t.text.strip.present? }
          return node unless text_node

          text_node.content = text_node.text.sub(/\A\s*#{number}\.\s*/, "")
          return nil if node.text.strip.empty? && node.css("img, table").empty?

          node
        end

        def self.classify_node(node, state)
          text = node.text.strip

          if metadata_line?(text)
            state[:metadata].merge!(parse_metadata(text))
          elsif (m = text.match(ANSWER_RE))
            state[:answers] << { part: m[1]&.to_i, text: m[2].strip }
          elsif (m = text.match(GROUP_RE)) && node.css("img, table").empty?
            state[:current_group] = { title: text.chomp(":"), choose: m[2].to_i, options: [] }
            state[:groups] << state[:current_group]
          elsif (m = text.match(OPTION_RE)) && node.css("img, table").empty? && !indexed_answer?(m, state)
            option = { letter: m[1], label: m[2].strip }
            (state[:current_group] ? state[:current_group][:options] : state[:options]) << option
          elsif state[:seen_blank] && (m = text.match(/\A(\d+)\.\s+(.+)\z/m)) && m[1].to_i == state[:indexed_answer_next]
            state[:answers] << { part: m[1].to_i, text: m[2].strip }
            state[:indexed_answer_next] += 1
          else
            state[:seen_blank] ||= text.match?(BLANK_MARKER)
            state[:stem] << node
          end
        end

        # "A. 12" after a blank marker could theoretically be an indexed answer,
        # but indexed answers are digits — the OPTION_RE letter match already
        # disambiguates. This hook exists for clarity and future-proofing.
        def self.indexed_answer?(_match, _state)
          false
        end

        def self.metadata_line?(text)
          text.match?(/\AQuestion ID:/i)
        end

        # Pipe-split, but a segment without a recognized "key:" prefix is
        # appended to the previous value (handles pipes inside Rationale text).
        def self.parse_metadata(text)
          result = {}
          last_key = nil
          text.split("|").each do |segment|
            key, value = segment.split(":", 2)
            normalized = key.to_s.strip.downcase
            if value && METADATA_KEYS.include?(normalized)
              result[normalized] = value.strip
              last_key = normalized
            elsif last_key
              result[last_key] = [result[last_key], segment.strip].reject(&:empty?).join(" | ")
            end
          end
          result
        end

        def self.build_question(number, state)
          stem_html = state[:stem].map(&:to_html).join("\n")
          type = classify_type(stem_html, state)
          state[:warnings] << "Question #{number}: could not determine question type — skipped" if type == :unknown

          ParsedQuestion.new(
            number: number,
            type: type,
            stem_html: stem_html,
            options: state[:options],
            groups: state[:groups],
            metadata: state[:metadata],
            answers: state[:answers],
            warnings: state[:warnings],
          )
        end

        def self.classify_type(stem_html, state)
          stem_text = Nokogiri::HTML.fragment(stem_html).text

          if state[:groups].length >= 2
            :bowtie
          elsif state[:options].any?
            if stem_text.match?(/drag the correct answer/i)
              :drag_and_drop
            elsif stem_text.match?(/select all that apply|mark all that apply/i) || multi_letter_answer?(state)
              :multiple_response
            else
              :multiple_choice
            end
          elsif state[:answers].any?
            :fitb
          else
            :unknown
          end
        end

        def self.multi_letter_answer?(state)
          answer = state[:answers].first&.dig(:text) || ""
          answer.scan(/\b([A-O])[.,;]/).length > 1
        end
      end
    end
  end
end
