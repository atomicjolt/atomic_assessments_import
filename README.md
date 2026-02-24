# Atomic Assessments Import

Import converters for atomic assessments.  Currently this GEM supports the following export and file types:
* CSV 
    - Multiple Choice
* ExamSoft (in RTF, HTML, or DOCX file format)
    - Multiple Choice
    - True/False
    - Fill in the Blank / Cloze
    - Ordering
    - Essay

For QTI conversion, see:

https://github.com/atomicjolt/qti_to_learnosity_converter


## Installation

To install for standalone use:

    $ bundle install

To use in another ruby application, install the gem and add to the application's Gemfile by executing:

    $ bundle add atomic_assessments_import

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install atomic_assessments_import

## Usage
```
Usage: bin/convert <file> <export_path> [converter]
  <file>          Path to CSV or RTF file to convert
  <export_path>   Path for output ZIP file
  [converter]     Which converter to use- 'examsoft' for files coming from ExamSoft, 'csv' for standard CSV files. Defaults to csv if not specified.
```

## Standalone conversion scripts

Convert a CSV to a learnosity archive:

    $ bin/convert input.csv output.zip

Convert a CSV to json on standard out:

    $ bin/convert_to_json input.csv

Convert an ExamSoft RTF to a learnosity archive:

    $ bin/convert input.rtf output.zip examsoft

## CSV input format

All columns are optional execpt "Option A", "Option B", and "Correct Answer".

| Column Name                   | Description |
|--------------------------------|-------------|
| Question ID               | External question id. Importing the same question ID twice into a course will overwrite previous imports. Omit this to generate a random id |
| Title                     | Item title |
| Question Text             | Question stem |
| Question Type             | Currently only supports "Multiple choice" |
| Template                  | Question type template. One of: <br />- Standard <br />- Block layout <br />- Multiple response <br />- Block layout multiple response <br />- Choice matrix <br />- Choice matrix inline <br />- Choice matrix labels <br />"Standard" and "Block layout" are single response question types. The other templates are multiple response. The default is "Standard" |
| Correct Answer            | Correct response option, e.g., "A". <br />For multiple response questions, use a semicolon separator, e.g., "A;C;D" |
| Points                    | Question points, defaults to 1 |
| Option A                  | Text for option A |
| Option B                  | Text for option B |
| Option C                  | Text for option C |
| Option [D-O]              | Text for subsequent options |
| Option A Feedback         | Feedback for option A |
| Option B Feedback         | Feedback for option B |
| Option C Feedback         | Feedback for option C |
| Option [D-O] Feedback     | Feedback for subsequent options |
| Scoring Type              | Learnosity scoring type. One of: <br />- Partial Match Per Response <br />- Partial Match <br />- Exact Match <br />The default is "Partial Match Per Response" |
| Shuffle options           | Whether to shuffle answers. One of: <br />- Yes <br />- No <br />Default is "No" |
| General Feedback          | General feedback |
| Correct Feedback          | Correct feedback |
| Partially Correct Feedback| Partially correct feedback |
| Incorrect Feedback        | Incorrect feedback |
| Distractor Rationale      | Distractor rationale feedback |
| Stimulus review           | Stimulus (review only) |
| Acknowledgements          | Acknowledgements |
| Instructor stimulus       | Instructor stimulus |
| Sample Answer             | Sample answer |
| Description               | Item description |
| Tag: tag_type             | Entries in this column represent tag names in type "tag_type". This column can be repeated any number of times with the same or multiple tag types |
| Alignment URL             | URL used to generate standard alignment tags. This column can be repeated |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/atomicjolt/atomic_assessments_import.
