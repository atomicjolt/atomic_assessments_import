# frozen_string_literal: true

require "byebug"
require "csv"
require "active_support/core_ext/digest/uuid"

require_relative "questions/question"
require_relative "questions/multiple_choice"

module AtomicAssessmentsImport
  module CSV
    module Utils
      def self.parse_boolean(value, default:)
        case value&.downcase
        when "true", "yes", "y", "1"
          true
        when "false", "no", "n", "0"
          false
        else
          default
        end
      end
    end
  end
end
