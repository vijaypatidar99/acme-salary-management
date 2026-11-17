# JSON shape of a salary record (docs/api-contracts.md §2 and §3). Money and rates are decimal strings,
# timestamps ISO 8601 UTC with microseconds. Annual values come from the shared Compensation rules.
class SalaryRecordSerializer
  def self.call(record)
    {
      id: record.id,
      amount: DecimalString.call(record.amount),
      currency: record.currency_code,
      pay_frequency: record.pay_frequency,
      fx_rate: DecimalString.call(record.fx_rate, scale: 8),
      annual_base_local: DecimalString.call(record.annual_local),
      annual_base_reporting: DecimalString.call(record.annual_reporting),
      effective_from: Timestamp.call(record.effective_from),
      effective_to: Timestamp.call(record.effective_to),
      reason: record.reason,
      is_current: record.current?
    }
  end
end
