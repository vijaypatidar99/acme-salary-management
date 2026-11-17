require "rails_helper"

RSpec.describe Employees::CsvExport do
  describe ".sanitize (docs/api-contracts.md §5 required cases, before RFC 4180 quoting)" do
    {
      "=1+1" => "'=1+1", "+1" => "'+1", "-1" => "'-1", "@SUM(A1)" => "'@SUM(A1)",
      " =1+1" => "' =1+1", "  -2" => "'  -2", " @x" => "' @x",
      "\t=1+1" => "'\t=1+1", "\r=1+1" => "'\r=1+1", "\n=1+1" => "'\n=1+1",
      " =1+1" => "' =1+1", # non-breaking space before the formula character
      "=HYPERLINK(\"http://x\",\"y\")" => "'=HYPERLINK(\"http://x\",\"y\")",
      "-100.00" => "'-100.00",
      "Smith, John" => "Smith, John", "say \"hi\"" => "say \"hi\"", "line1\nline2" => "line1\nline2",
      "Engineering" => "Engineering", "O-Neil" => "O-Neil", "a=b" => "a=b", "" => ""
    }.each do |input, expected|
      it "turns #{input.inspect} into #{expected.inspect}" do
        expect(described_class.sanitize(input)).to eq(expected)
      end
    end

    it "leaves nil as nil so it becomes an empty field" do
      expect(described_class.sanitize(nil)).to be_nil
    end
  end

  describe ".encode_field (RFC 4180)" do
    it "quotes fields with commas, quotes, CR or LF and doubles embedded quotes" do
      expect(described_class.encode_field("Smith, John")).to eq("\"Smith, John\"")
      expect(described_class.encode_field("say \"hi\"")).to eq("\"say \"\"hi\"\"\"")
      expect(described_class.encode_field("line1\nline2")).to eq("\"line1\nline2\"")
      expect(described_class.encode_field("a\rb")).to eq("\"a\rb\"")
      expect(described_class.encode_field("plain")).to eq("plain")
    end

    it "writes missing values as empty fields" do
      expect(described_class.encode_field(nil)).to eq("")
    end

    it "quotes a sanitized formula that also contains special characters" do
      cell = described_class.encode_field(described_class.sanitize("=HYPERLINK(\"http://x\",\"y\")"))

      expect(cell).to eq("\"'=HYPERLINK(\"\"http://x\"\",\"\"y\"\")\"")
    end

    it "ends each line with CRLF" do
      expect(described_class.encode_line(%w[a b])).to eq("a,b\r\n")
    end
  end

  describe "numeric and date columns are never prefixed" do
    CsvFakeEmployee = Struct.new(:values) do
      def [](key) = values[key.to_s]
      def employee_number = "ACME-1"
      def first_name = "A"
      def last_name = "B"
      def country_code = "IN"
      def job_title = "T"
      def job_level = 3
      def employment_status = "active"
      def hired_on = Date.new(2019, 4, 1)
      def terminated_on = nil
    end

    it "keeps a negative number in a numeric column intact and writes NULL dates as empty fields" do
      employee = CsvFakeEmployee.new({ "salary_amount" => BigDecimal("-100.00"), "annual_base_local" => BigDecimal("-1200"),
                                  "salary_fx_rate" => BigDecimal("0.012"), "annual_base_reporting" => BigDecimal("-14.40"),
                                  "salary_effective_from" => Time.utc(2025, 4, 1), "salary_currency" => "INR",
                                  "salary_pay_frequency" => "monthly", "department_name" => "Engineering", "country_name" => "India" })
      directory = instance_double(Employees::Directory)
      allow(directory).to receive(:each_batch).and_yield([ employee ])

      header, row = described_class.new(directory).each_line.to_a

      expect(header).to eq("#{described_class::COLUMNS.map(&:first).join(',')}\r\n")
      expect(row).to eq("ACME-1,A,B,Engineering,IN,India,T,3,active,2019-04-01,,-100.00,INR,monthly,-1200.00,0.01200000,-14.40,2025-04-01T00:00:00Z\r\n")
    end
  end
end
