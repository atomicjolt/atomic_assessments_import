# frozen_string_literal: true

require "securerandom"
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
            "template" => parsed.type == :multiple_response ? "block layout multiple response" : "block layout",
          )
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

        def self.build_fitb(parsed, warnings)
          if parsed.answers.empty?
            raise MissingAnswerError,
                  "no answer key found — request an ExamSoft export that includes answers"
          end

          multi = parsed.answers.length > 1
          parsed.answers.map.with_index do |answer, idx|
            primary, alternates = split_alternates(answer[:text])
            if alternates.any?
              warnings << "Question #{parsed.number}: comma-separated answer treated as alternates — review scoring"
            end

            stimulus =
              if idx.zero?
                multi ? "#{parsed.stem_html}\n<p><strong>Part 1</strong></p>" : parsed.stem_html
              else
                "<p><strong>Part #{answer[:part] || idx + 1}</strong></p>"
              end

            row = base_row(parsed).merge(
              "question type" => "short_answer",
              "question text" => stimulus,
              "correct answer" => primary,
              "alternate answers" => alternates,
            )
            Questions::Question.load(row).to_learnosity
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
