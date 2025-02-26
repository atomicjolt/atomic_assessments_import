# AtomicAssessmentsImports

Import converters for atomic assessments

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add atomic_assessments_imports

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install atomic_assessments_imports

## Conversion scripts

Convert a CSV to a learnosity archive:

    $ bin/convert input.csv output.zip

Convert a CSV to json:

    $ bin/convert_to_json input.csv

## CSV input format

CSV Columns:

### Question ID
  External question id.  Importing the same question ID twice will overwrite previous imports
### Title
  Item title
### Tag: tag_type
  Entries in this column represent tag names in type "tag_type".  This column can be repeated any number of times with multiple tag types.
### Question Text
  Question stem
### Question Type
  Question type. One of:
  - Multiple choice (default)
### Template
  Question type template.  One of:
  - Standard (default)
  - Block layout
  - Multiple response
  - Block layout multiple response
  - Choice matrix
  - Choice matrix inline
  - Choice matrix labels
  "Standard" and "Block layout" are single response question types.  The other templates are multiple response.
### Correct Answer
  Correct response option, e.g. "A"
  For multiple response questions, use a semicolon separator.  e.g. "A;C;D"
### Option A
  Text for option A
### Option B
  Text for option B
### Option C through Option O
  Text for subsequent options
### Option A Feedback
  Feedback for option A
### Option B Feedback
  Feedback for option B
### Option C Feedback through Option O Feedback
  Feedback for subsequent options
### Scoring Type
  Learnosity scoring type.  One of:
  - Partial Match Per Response (default)
  - Partial Match
  - Exact Match
### Shuffle options
  Whether to shuffle answers. One of:
  - Yes
  - No (default)
### Points
  Question points (default 1)
### General Feedback
  General feedback
### Correct Feedback
  Correct feedback
### Partially Correct Feedback
  Partially correct feedback
### Incorrect Feedback
  Incorrect feedback
### Distractor Rationale
  Distractor rationale feedback
### Stimulus review
  Stimulus (review only)
### Acknowledgements
  Acknowledgements
### Instructor stimulus
  Instructor stimulus
### Sample Answer
  Sample answer
### Description
  Item description
### Alignment URL
  URL used to generate standard alignment tags. This column can be repeated.




## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/atomicjolt/atomic_assessments_imports.
