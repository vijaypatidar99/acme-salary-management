module Api
  module V1
    # The only write endpoint. Order of checks (docs/api-contracts.md): 403 → 401 → 400 → 404 → the
    # service's 409/422 rules.
    class SalaryRevisionsController < ApplicationController
      include WriteKeyAuthentication

      before_action :authenticate_write_key!

      def create
        input = revision_params # Structural errors precede employee lookup errors, including malformed IDs.
        result = SalaryRevisions::Create.call(employee_id: employee_id_param(:employee_id), params: input)
        render json: { data: SalaryRevisionSerializer.call(result) }, status: :created
      end

      private

      # Structural checks only (400): the salary_revision object, JSON types, and an integer token.
      # A null field counts as absent and is reported by the service as 422 validation_failed.
      def revision_params
        raw = params[:salary_revision]
        raise invalid_request("salary_revision object is required") unless raw.is_a?(ActionController::Parameters)

        {
          amount: text_field(raw, :amount),
          currency: text_field(raw, :currency),
          pay_frequency: text_field(raw, :pay_frequency),
          reason: text_field(raw, :reason),
          expected_current_salary_record_id: token_field(raw)
        }
      end

      def text_field(raw, name)
        value = raw[name]
        return value if value.nil? || value.is_a?(String)

        raise invalid_request("#{name} must be a string")
      end

      def token_field(raw)
        value = raw[:expected_current_salary_record_id]
        return value if value.is_a?(Integer)

        raise invalid_request("expected_current_salary_record_id must be an integer")
      end

      def invalid_request(message)
        DomainError.new("invalid_request", message)
      end
    end
  end
end
