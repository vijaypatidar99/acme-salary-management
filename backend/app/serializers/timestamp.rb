# ISO 8601 UTC with microseconds: 2026-11-17T09:30:00.123456Z
module Timestamp
  module_function

  def call(time)
    time&.utc&.iso8601(6)
  end
end
