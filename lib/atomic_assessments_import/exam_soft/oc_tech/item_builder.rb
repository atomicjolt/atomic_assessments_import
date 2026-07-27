# frozen_string_literal: true

require "securerandom"
require "nokogiri"
require_relative "question_parser"
require_relative "../../questions/question"

module AtomicAssessmentsImport
  module ExamSoft
    module OcTech
      module ItemBuilder
        class MissingAnswerError < StandardError; end

        LETTER_SCAN = /\b([A-O])(?:[.,;]|\s|\z)/

        def self.build(parsed, exam_title:)
          raise ArgumentError, "unknown-type questions cannot be built" if parsed.type == :unknown

          warnings = []
          questions = build_questions(parsed, warnings)

          item = {
            reference: SecureRandom.uuid,
            title: item_title(parsed, exam_title),
            status: "published",
            tags: categories_tags(parsed.metadata["categories"]),
            metadata: {
              import_date: Time.now.iso8601,
              import_type: "examsoft_octech",
            },
            source: source_note(parsed),
            description: "",
            questions: questions.map { |q| { reference: q[:reference], type: q[:data][:type] } },
            features: [],
            definition: {
              widgets: questions.map { |q| { reference: q[:reference], widget_type: "response" } },
            },
          }

          { item: item, questions: questions, warnings: warnings }
        end

        def self.build_questions(parsed, warnings)
          case parsed.type
          when :multiple_choice, :multiple_response
            [build_mc(parsed)]
          when :drag_and_drop
            [build_classification(parsed)]
          when :fitb
            build_fitb(parsed, warnings)
          when :bowtie
            warnings << "Question #{parsed.number}: bowtie imported without scoring — set the correct response in authoring"
            [build_bowtie(parsed)]
          end
        end

        def self.base_row(parsed)
          {
            "question text" => parsed.stem_html,
            "points" => parsed.metadata["point value"],
            "general feedback" => parsed.metadata["rationale"],
          }
        end

        def self.answer_letters(parsed)
          text = parsed.answers.map { |a| a[:text] }.join("; ")
          letters = text.scan(LETTER_SCAN).flatten.compact.map(&:downcase).uniq
          if letters.empty?
            raise MissingAnswerError,
                  "no answer key found — request an ExamSoft export that includes answers"
          end

          letters.join(";")
        end

        def self.build_mc(parsed)
          if parsed.answers.empty?
            raise MissingAnswerError,
                  "no answer key found — request an ExamSoft export that includes answers"
          end

          row = base_row(parsed).merge(
            "question type" => "multiple choice",
            "correct answer" => answer_letters(parsed),
          )
          row["template"] = "multiple response" if parsed.type == :multiple_response
          parsed.options.each do |option|
            row["option #{option[:letter].downcase}"] = option[:label]
          end
          Questions::Question.load(row).to_learnosity
        end

        def self.build_classification(parsed)
          if parsed.answers.empty?
            raise MissingAnswerError,
                  "no answer key found — request an ExamSoft export that includes answers"
          end

          row = base_row(parsed).merge(
            "question type" => "classification",
            "possible responses" => parsed.options.map { |o| o[:label] },
            "correct answer" => answer_letters(parsed),
          )
          Questions::Question.load(row).to_learnosity
        end

        FITB_MARKER_RE = /__\d+__|_{3,}/

        def self.build_fitb(parsed, warnings)
          if parsed.answers.empty?
            raise MissingAnswerError,
                  "no answer key found — request an ExamSoft export that includes answers"
          end

          ordered = order_fitb_answers(parsed.answers)
          multi = ordered.length > 1
          primary_texts, alternate_answers = fitb_answer_texts(ordered, multi, parsed.number, warnings)

          if primary_texts.any? { |text| text.include?(";") }
            warnings << "Question #{parsed.number}: answer contains a semicolon — review scoring"
          end

          question_text = build_fitb_template(parsed, primary_texts, warnings)

          row = base_row(parsed).merge(
            "question type" => "fill_in_the_blank",
            "question text" => question_text,
            "correct answer" => primary_texts.join(";"),
            "alternate answers" => alternate_answers,
          )
          [Questions::Question.load(row).to_learnosity]
        end

        # Parts are sorted by part number when every answer carries one;
        # answers without parts are already in document (position) order.
        def self.order_fitb_answers(answers)
          return answers.sort_by { |a| a[:part] } if answers.all? { |a| a[:part] }

          answers
        end

        # Comma-alternates (e.g. "0, none") only make sense for a single
        # blank — for multi-part questions we fall back to primaries only
        # and warn instead of guessing which blank an alternate belongs to.
        def self.fitb_answer_texts(ordered, multi, number, warnings)
          if multi
            has_alternates = false
            primary_texts = ordered.map do |answer|
              primary, alternates = split_alternates(answer[:text])
              has_alternates ||= alternates.any?
              primary
            end
            if has_alternates
              warnings << "Question #{number}: alternates on multi-blank questions are not supported — review scoring"
            end
            [primary_texts, []]
          else
            primary, alternates = split_alternates(ordered.first[:text])
            if alternates.any?
              warnings << "Question #{number}: comma-separated answer treated as alternates — review scoring"
            end
            [[primary], alternates]
          end
        end

        # Pre-place {{response}} markers so FillInTheBlank#build_stimulus
        # passes the text through unchanged (it only templates text that
        # doesn't already contain {{response}}).
        #
        # Markers are scanned and replaced only within visible TEXT nodes —
        # never in the raw HTML string — so that literal underscore runs in
        # attribute values (e.g. the ___EXPORT_ROOT___ asset path rewritten
        # into <img src="___EXPORT_ROOT___/assets/...">) are never mistaken
        # for fill-in-the-blank markers or corrupted by substitution.
        def self.build_fitb_template(parsed, primary_texts, warnings)
          stem = parsed.stem_html
          appended = primary_texts.map { |_| "<p>{{response}}</p>" }.join

          fragment = Nokogiri::HTML.fragment(stem)
          text_nodes = fragment.xpath(".//text()")
          marker_count = text_nodes.sum { |node| node.content.scan(FITB_MARKER_RE).length }

          if marker_count.zero?
            stem + appended
          elsif marker_count == primary_texts.length
            replace_markers_in_text_nodes(text_nodes, primary_texts.length)
            fragment.to_html
          else
            warnings << "Question #{parsed.number}: blank markers don't match answer count — review layout"
            stem + appended
          end
        end

        # Replaces the first `remaining` FITB_MARKER_RE matches across the
        # given text nodes, in document order, with {{response}}.
        def self.replace_markers_in_text_nodes(text_nodes, remaining)
          text_nodes.each do |node|
            break if remaining.zero?

            node.content = node.content.gsub(FITB_MARKER_RE) do |match|
              remaining.positive? ? (remaining -= 1) && "{{response}}" : match
            end
          end
        end

        # Split "0, none" into primary + alternates, but never split purely
        # numeric values like "1,000".
        def self.split_alternates(text)
          parts = text.split(/,\s*/).map(&:strip).reject(&:empty?)
          return [text, []] unless parts.length > 1 && parts.any? { |p| p.match?(/[a-zA-Z]/) }

          [parts.first, parts[1..]]
        end

        def self.build_bowtie(parsed)
          groups = center_choose_one(parsed.groups).map do |group|
            { title: group[:title], responses: group[:options].map { |o| o[:label] } }
          end
          row = base_row(parsed).merge(
            "question type" => "bowtie",
            "response groups" => groups,
          )
          Questions::Question.load(row).to_learnosity
        end

        def self.center_choose_one(groups)
          center = groups.find { |g| g[:choose] == 1 }
          return groups unless center && groups.length == 3

          outer = groups - [center]
          [outer[0], center, outer[1]]
        end

        def self.item_title(parsed, exam_title)
          parsed.metadata["question id"].presence || "#{exam_title} — Question #{parsed.number}"
        end

        def self.source_note(parsed)
          note = "<p>ExamSoft (OC Tech) Import on #{Time.now.strftime('%Y-%m-%d')}</p>\n"
          note += "<p>External id: #{parsed.metadata['question id']}</p>\n" if parsed.metadata["question id"].present?
          note
        end

        # Same Key/Value tag convention as ExamSoft::Converter#categories_to_tags;
        # OC Tech's Categories field is a single string, split on ";".
        def self.categories_tags(categories)
          tags = {}
          (categories || "").split(";").each do |cat|
            parts = cat.to_s.split("/")
            key = parts.shift&.strip
            value = parts.join("/").strip
            next if key.blank? || value.blank?

            key = key.delete(":")[0, 255]
            value = value[0, 255]
            next if key.blank? || value.blank?

            tags[key.to_sym] ||= []
            tags[key.to_sym] |= [value]
          end
          tags
        end
      end
    end
  end
end
