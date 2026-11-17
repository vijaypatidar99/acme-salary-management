# Renders errors in the shape defined by docs/api-contracts.md ("Error shape"):
#   { "error": { "code": "...", "message": "...", "details": { ... } } }
# `details` is optional. Only the codes that need no business rule live here;
# endpoint-specific codes (409, 422, ...) are raised by their own phases.
module ApiErrorHandling
  extend ActiveSupport::Concern

  included do
    # Handlers are matched last-declared-first, so the catch-all comes first.
    rescue_from StandardError, with: :render_internal_error
    rescue_from ActiveRecord::StatementInvalid, with: :render_database_error
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
    rescue_from DomainError, with: :render_domain_error
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::ParameterMissing,
                ActionController::BadRequest,
                ActionDispatch::Http::Parameters::ParseError, with: :render_invalid_request
  end

  def route_not_found
    render_error :not_found, "not_found", "Not found"
  end

  private

  def render_error(status, code, message, details: nil)
    body = { code: code, message: message }
    body[:details] = details if details
    render json: { error: body }, status: status
  end

  def render_domain_error(error)
    render_error error.status, error.code, error.message, details: error.details
  end

  def render_record_invalid(error)
    render_error :unprocessable_entity, "validation_failed", error.message, details: error.record.errors.to_hash
  end

  # A constraint the application checks should have caught first. Map the violation without leaking
  # SQL, constraint or table names: overlap/uniqueness is a conflict, the rest is invalid data.
  def render_database_error(error)
    case error
    when ActiveRecord::ExclusionViolation, ActiveRecord::RecordNotUnique
      render_error :conflict, "revision_conflict", "The request conflicts with existing data"
    when ActiveRecord::CheckViolation, ActiveRecord::NotNullViolation, ActiveRecord::InvalidForeignKey,
         ActiveRecord::RangeError, ActiveRecord::ValueTooLong
      render_error :unprocessable_entity, "validation_failed", "The data violates a database constraint"
    else
      render_internal_error(error)
    end
  end

  def render_not_found(_exception)
    render_error :not_found, "not_found", "Not found"
  end

  def render_invalid_request(_exception)
    render_error :bad_request, "invalid_request", "The request is malformed"
  end

  # Exception messages can contain credentials or request input. Keep only the failure class and
  # code locations; parameter filtering cannot sanitize arbitrary interpolated exception messages.
  def render_internal_error(exception)
    Rails.logger.error("#{exception.class}: unexpected request failure\n#{exception.backtrace&.first(15)&.join("\n")}")
    render_error :internal_server_error, "internal_error", "Something went wrong"
  end
end
