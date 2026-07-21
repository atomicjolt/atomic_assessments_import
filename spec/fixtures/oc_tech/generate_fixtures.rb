# frozen_string_literal: true

# Regenerates the OC Tech RTF fixtures. Run from the gem root:
#   ruby spec/fixtures/oc_tech/generate_fixtures.rb
# The fixtures mimic ExamSoft's minimal RTF dialect (bold numbered stems,
# tab-indented options) with a real embedded PNG for image testing.

require "zlib"

DIR = __dir__

# Minimal valid 1x1 red PNG, built programmatically so the bytes are correct.
def chunk(type, data)
  [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
end

def png_bytes
  ihdr = chunk("IHDR", [1, 1, 8, 2, 0, 0, 0].pack("NNC5"))
  idat = chunk("IDAT", Zlib::Deflate.deflate("\x00\xFF\x00\x00".b))
  iend = chunk("IEND", "")
  "\x89PNG\r\n\x1a\n".b + ihdr + idat + iend
end

PICT = "{\\pict\\pngblip\\picw1\\pich1 #{png_bytes.unpack1('H*')}}"

File.write(File.join(DIR, "practice_exam.rtf"), <<~RTF)
  {\\rtf1\\ansi\\ansicpg1252\\deff0\\deflang1033
  {\\fonttbl{\\f0\\froman\\fcharset0 Times New Roman;}}
  \\viewkind4\\uc1\\pard\\f0\\fs24
  \\b\\fs32 OC Tech Practice Exam\\b0\\fs24\\par
  \\par
  Date and Time of Exam Creation: 08/31/2024 11:31AM EDT | Total Exam Points: 60 | Est. Completion Time: 13mins\\par
  Avg. Point Biserial: 0.43 | Difficulty: 0.95 | Total Questions: 3 | Fill in the Blank: 2 | Multiple Choice: 1\\par
  \\par
  \\par\\b 1. \\b0 #{PICT}\\par
  READ THE LABEL ABOVE CAREFULLY\\par
  How many mL should the nurse administer? ___________\\par
  Question ID: 34643 | Point Value: 20 | Categories:\\par
  \\b Answer: 1.7\\b0\\par
  \\par
  \\par\\b 2. How many milliliters will the patient receive per dose?\\b0\\par
  \\tab A. 12\\par
  \\tab B. 15\\par
  \\tab C. 20\\par
  \\tab D. 10\\par
  Question ID: 23271 | Point Value: 20 | Rationale: 150 mg / 15 mg/mL = 10 | Categories:\\par
  \\b Answer: D. 10\\b0\\par
  \\par
  \\par\\b 3. How long will it take, and what time will it complete?\\b0\\par
  Question ID: 34641 | Point Value: 20 | Categories:\\par
  \\b Answer Part 1: 8 hours 20 minutes\\b0\\par
  \\b Answer Part 2: 1420\\b0\\par
  \\par
  }
RTF

File.write(File.join(DIR, "no_answers.rtf"), <<~RTF)
  {\\rtf1\\ansi\\ansicpg1252\\deff0\\deflang1033
  {\\fonttbl{\\f0\\froman\\fcharset0 Times New Roman;}}
  \\viewkind4\\uc1\\pard\\f0\\fs24
  \\b\\fs32 OC Tech Test Without Answers\\b0\\fs24\\par
  \\par
  Avg. Point Biserial: 0.2 | Difficulty: 0.8 | Total Questions: 1 | Multiple Choice: 1\\par
  \\par
  \\par\\b 1. Which class of drugs is especially useful?\\b0\\par
  \\tab A. Macrolides\\par
  \\tab B. Sulfonamides\\par
  \\par
  }
RTF

puts "wrote fixtures to #{DIR}"
