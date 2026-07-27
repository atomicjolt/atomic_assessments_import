# frozen_string_literal: true

require "pandoc-ruby"
require "nokogiri"
require "active_support/core_ext/digest/uuid"
require "tmpdir"
require "securerandom"
require "zip"
require "tempfile"

require_relative "../utils"
require_relative "classic_pipeline"
require_relative "html_normalizer"
require_relative "format_detector"

module AtomicAssessmentsImport
  module ExamSoft
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

      # One exam document → items + one activity. Public: the zip path
      # (Task 5) calls it per entry and finalizes once, zip-wide.
      def convert_single(path, filename:)
        Dir.mktmpdir("examsoft_media") do |media_dir|
          html = PandocRuby.new([path], from: source_format(path), "extract-media" => media_dir).to_html
          doc = Nokogiri::HTML.fragment(html)
          HtmlNormalizer.normalize!(doc)
          assets = collect_assets!(doc, media_dir)

          format = FormatDetector.detect(doc)
          pipeline = format ? format[:pipeline] : ClassicPipeline
          result = pipeline.convert_document(doc)

          title = result[:title].presence || File.basename(filename, ".*")
          errors = result[:errors].each { |e| e[:message] = "#{filename}: #{e[:message]}" }
          raise AtomicAssessmentsImport::Error, "#{filename}: no questions could be converted" if result[:items].empty?

          {
            activities: [build_activity(title, result[:items])],
            items: result[:items],
            questions: result[:questions],
            features: result[:features],
            assets: assets,
            errors: errors,
          }
        end
      rescue OcTech::ItemBuilder::MissingAnswerError => e
        raise AtomicAssessmentsImport::Error, "#{filename}: #{e.message}"
      rescue AtomicAssessmentsImport::Error
        raise
      rescue StandardError => e
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

        unless converted_any
          details = merged[:errors].map { |e| e[:message] }.join("; ")
          suffix = details.empty? ? "" : ": #{details}"
          raise AtomicAssessmentsImport::Error, "No files in the zip could be converted#{suffix}"
        end

        merged
      end

      def skip_entry?(name)
        name.start_with?("__MACOSX/") || File.basename(name).start_with?(".")
      end

      def convert_zip_entry(entry, merged)
        filename = File.basename(entry.name)

        Tempfile.create(["examsoft_entry", File.extname(entry.name)]) do |tmp|
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

      def build_error(message, filename, error_type: "warning", question_type: nil)
        {
          error_type: error_type,
          question_type: question_type,
          message: "#{filename}: #{message}",
          qti_item_id: nil,
          index: nil,
        }
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
          next unless File.exist?(local) &&
                      File.expand_path(local).start_with?("#{File.expand_path(media_dir)}#{File::SEPARATOR}")

          zip_path = "assets/#{File.basename(local)}"
          assets[zip_path] = File.binread(local)
          img["src"] = "___EXPORT_ROOT___/#{zip_path}"
          img.remove_attribute("style")
        end
        assets
      end

      # NOTE(#2237): one activity per source file. The issue also asks that a single
      # file containing MULTIPLE exams split into one activity each — deferred until a
      # real classic-format sample shows what an exam boundary looks like (we have no
      # sample defining one). Revisit when such a file exists.
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
    end
  end
end
