# frozen_string_literal: true

require "pandoc-ruby"
require "nokogiri"
require "tmpdir"
require "securerandom"
require "zip"
require "tempfile"
require_relative "../html_normalizer"
require_relative "document_parser"
require_relative "question_parser"
require_relative "item_builder"

module AtomicAssessmentsImport
  module ExamSoft
    module OcTech
      class Converter
        SUPPORTED_EXTENSIONS = %w[.rtf .docx .html .htm].freeze

        def initialize(file)
          @file = file
        end

        def convert
          path = @file.is_a?(String) ? @file : @file.path
          result =
            if File.extname(path).casecmp(".zip").zero?
              convert_zip(path)
            else
              convert_single(path, filename: File.basename(path))
            end
          finalize_errors(result)
        end

        # Convert one exam document to items + one activity. Used directly for
        # single files and per-entry by the zip path (Task 10).
        def convert_single(path, filename:)
          Dir.mktmpdir("oc_tech_media") do |media_dir|
            html = PandocRuby.new([path], from: source_format(path), "extract-media" => media_dir).to_html
            doc = Nokogiri::HTML.fragment(html)
            HtmlNormalizer.normalize!(doc)

            assets = collect_assets!(doc, media_dir)
            parsed_doc = DocumentParser.parse(doc)
            title = parsed_doc[:title].presence || File.basename(filename, ".*")
            errors = parsed_doc[:warnings].map { |w| build_error(w, filename) }

            items, questions = build_items(parsed_doc[:blocks], title, filename, errors)
            raise AtomicAssessmentsImport::Error, "#{filename}: no questions could be converted" if items.empty?

            errors.concat(declared_count_errors(parsed_doc, filename))

            {
              activities: [build_activity(title, items)],
              items: items,
              questions: questions,
              features: [],
              assets: assets,
              errors: errors,
            }
          end
        rescue ItemBuilder::MissingAnswerError => e
          raise AtomicAssessmentsImport::Error, "#{filename}: #{e.message}"
        rescue AtomicAssessmentsImport::Error
          raise
        rescue StandardError => e
          # Pandoc/Nokogiri/etc. can raise bare RuntimeErrors (e.g. a corrupt
          # .docx). Wrap so the failure names the offending file instead of
          # bubbling up an anonymous error that aborts the whole zip.
          raise AtomicAssessmentsImport::Error, "#{filename}: #{e.message}"
        end

        private

        # Assigns each error a sequential, unique 0-based `index` across the
        # whole outgoing result (file-wide for a single file, zip-wide when
        # convert_single results have been merged). The Rails app persists
        # errors via find_or_create_by(qti_item_id:, index:), so without this
        # every error but the first would collide on the shared nil index and
        # be silently dropped.
        def finalize_errors(result)
          result[:errors].each_with_index { |error, index| error[:index] = index }
          result
        end

        def convert_zip(zip_path)
          merged = { activities: [], items: [], questions: [], features: [], assets: {}, errors: [] }
          converted_any = false

          Zip::File.open(zip_path) do |zip|
            zip.each do |entry|
              next unless entry.file?
              next if skip_entry?(entry.name)

              unless SUPPORTED_EXTENSIONS.include?(File.extname(entry.name).downcase)
                merged[:errors] << build_error("skipped unsupported file type", entry.name)
                next
              end

              converted = convert_zip_entry(entry, merged)
              converted_any ||= converted
            end
          end

          raise AtomicAssessmentsImport::Error, "No files in the zip could be converted" unless converted_any

          merged
        end

        def skip_entry?(name)
          name.start_with?("__MACOSX/") || File.basename(name).start_with?(".")
        end

        def convert_zip_entry(entry, merged)
          filename = File.basename(entry.name)

          Tempfile.create(["oc_tech_entry", File.extname(entry.name)]) do |tmp|
            tmp.binmode
            tmp.write(entry.get_input_stream.read)
            tmp.flush

            begin
              result = convert_single(tmp.path, filename: filename)
              merge_result!(merged, result)
              true
            rescue StandardError => e
              # convert_single wraps its own failures in
              # AtomicAssessmentsImport::Error, but this catches
              # StandardError (not just that class) as a safety net so any
              # exception escaping a single entry never aborts the rest of
              # the zip.
              merged[:errors] << build_error(e.message.sub("#{filename}: ", ""), filename, error_type: "error")
              false
            end
          end
        end

        def merge_result!(merged, result)
          %i[activities items questions features].each { |key| merged[key].concat(result[key]) }
          merged[:assets].merge!(result[:assets])
          merged[:errors].concat(result[:errors])
        end

        def build_items(blocks, title, filename, errors)
          items = []
          questions = []

          blocks.each_with_index do |nodes, index|
            parsed = QuestionParser.parse(nodes, index + 1)
            parsed.warnings.each { |w| errors << build_error(w, filename) }
            next if parsed.type == :unknown

            built = ItemBuilder.build(parsed, exam_title: title)
            built[:warnings].each { |w| errors << build_error(w, filename, question_type: parsed.type.to_s) }
            items << built[:item]
            questions.concat(built[:questions])
          end

          [items, questions]
        end

        def declared_count_errors(parsed_doc, filename)
          declared = parsed_doc[:declared_counts]["Total Questions"]
          return [] unless declared && declared != parsed_doc[:blocks].length

          [build_error("header declares #{declared} questions, parsed #{parsed_doc[:blocks].length}", filename)]
        end

        def source_format(path)
          ext = File.extname(path).delete(".").downcase
          ext = "html" if ext == "htm"
          ext
        end

        # Pull pandoc-extracted media into memory, keyed by zip path, and
        # rewrite <img src> to the ___EXPORT_ROOT___ convention the Rails
        # importer's upload_assets! expects.
        def collect_assets!(doc, media_dir)
          assets = {}
          doc.css("img").each do |img|
            src = img["src"].to_s
            local = File.expand_path(src.start_with?("/") ? src : File.join(media_dir, "..", src))
            local = File.join(media_dir, File.basename(src)) unless File.exist?(local)
            next unless File.exist?(local) && File.expand_path(local).start_with?(File.expand_path(media_dir))

            zip_path = "assets/#{File.basename(local)}"
            assets[zip_path] = File.binread(local)
            img["src"] = "___EXPORT_ROOT___/#{zip_path}"
            img.remove_attribute("style")
          end
          assets
        end

        def build_activity(title, items)
          {
            reference: SecureRandom.uuid,
            title: title,
            description: "",
            data: {
              config: { title: title },
              rendering_type: "assess",
              items: items.map { |i| { reference: i[:reference], id: i[:reference] } },
            },
            status: "published",
            tags: {},
          }
        end

        def build_error(message, filename, error_type: "warning", question_type: nil)
          {
            error_type: error_type,
            question_type: question_type,
            message: "#{filename}: #{message}",
            qti_item_id: nil,
            index: nil,
          }
        end
      end
    end
  end
end
