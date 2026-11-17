class ApplicationController < ActionController::API
  include ApiErrorHandling

  private

  # Active Record casts "42junk" to 42 for bigint lookups; API path IDs must be integers.
  def employee_id_param(name = :id)
    value = params[name]
    valid_format = params[:format].nil? || params[:format] == "json"
    raise ActiveRecord::RecordNotFound unless valid_format && value.is_a?(String) && value.match?(/\A[0-9]+\z/)

    value
  end
end
