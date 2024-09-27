module AtomicAssessmentsImports
  module Export
    def self.create(path, data)
      AtomicAssessmentsImports::Writer.new(path).open do |writer|
        writer.write("export.json", {version: 2.0}.to_json)

        data[:activities].each do |activity|
          writer.write("activities/#{activity[:reference]}.json", activity.to_json)
        end

        data[:questions].each do |question|
          writer.write("questions/#{question[:reference]}.json", question.to_json)
        end

        data[:items].each do |item|
          writer.write("items/#{item[:reference]}.json", item.to_json)
        end
      end
    end
  end
end
