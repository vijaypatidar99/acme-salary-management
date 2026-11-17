module Employees
  # Streams every directory row matching the filters as CSV (docs/api-contracts.md §5): header first,
  # then batches from Employees::Directory, so the whole result is never held in memory. Encoding is
  # hand-written RFC 4180 because the csv gem is not part of this application's dependencies.
  class CsvExport
    # [header, kind, extractor]. `:text` cells are sanitized against formula injection; `:verbatim`
    # cells (numbers and dates produced by the system) are written as they are, never prefixed.
    COLUMNS = [
      [ "employee_number", :text, ->(e) { e.employee_number } ],
      [ "first_name", :text, ->(e) { e.first_name } ],
      [ "last_name", :text, ->(e) { e.last_name } ],
      [ "department", :text, ->(e) { e["department_name"] } ],
      [ "country_code", :text, ->(e) { e.country_code } ],
      [ "country", :text, ->(e) { e["country_name"] } ],
      [ "job_title", :text, ->(e) { e.job_title } ],
      [ "job_level", :verbatim, ->(e) { e.job_level } ],
      [ "employment_status", :text, ->(e) { e.employment_status } ],
      [ "hired_on", :verbatim, ->(e) { e.hired_on&.iso8601 } ],
      [ "terminated_on", :verbatim, ->(e) { e.terminated_on&.iso8601 } ],
      [ "salary_amount", :verbatim, ->(e) { DecimalString.call(e["salary_amount"]) } ],
      [ "salary_currency", :text, ->(e) { e["salary_currency"] } ],
      [ "pay_frequency", :text, ->(e) { e["salary_pay_frequency"] } ],
      [ "annual_base_local", :verbatim, ->(e) { DecimalString.call(e["annual_base_local"]) } ],
      [ "fx_rate_to_usd", :verbatim, ->(e) { DecimalString.call(e["salary_fx_rate"], scale: 8) } ],
      [ "annual_base_usd", :verbatim, ->(e) { DecimalString.call(e["annual_base_reporting"]) } ],
      [ "salary_effective_from", :verbatim, ->(e) { e["salary_effective_from"]&.utc&.iso8601 } ]
    ].freeze

    # Prefix a risky text value with an apostrophe so a spreadsheet does not run it as a formula.
    # Risky: starts with TAB, CR or LF, or its first character after any leading whitespace/control
    # characters is = + - @.
    FORMULA_START = /\A[=+\-@]/
    LEADING_BLANKS = /\A[[:space:][:cntrl:]]+/

    def self.sanitize(text)
      return text if text.nil?

      value = text.to_s
      risky = value.start_with?("\t", "\r", "\n") || value.sub(LEADING_BLANKS, "").match?(FORMULA_START)
      risky ? "'#{value}" : value
    end

    # RFC 4180: quote a field containing a comma, double quote, CR or LF; double embedded quotes.
    def self.encode_field(value)
      return "" if value.nil?

      text = value.to_s
      text.match?(/[",\r\n]/) ? "\"#{text.gsub('"', '""')}\"" : text
    end

    def self.encode_line(values)
      "#{values.map { |value| encode_field(value) }.join(',')}\r\n"
    end

    def initialize(directory)
      @directory = directory
    end

    # Yields one CSV line at a time (header first); the response body iterates this lazily.
    def each_line
      return enum_for(:each_line) unless block_given?

      yield self.class.encode_line(COLUMNS.map(&:first))
      @directory.each_batch do |employees|
        employees.each { |employee| yield self.class.encode_line(row_for(employee)) }
      end
    end

    private

    def row_for(employee)
      COLUMNS.map do |_name, kind, extractor|
        value = extractor.call(employee)
        kind == :text ? self.class.sanitize(value) : value
      end
    end
  end
end
