# Lightweight demo protection for the one write endpoint (docs/architecture.md §9.3, DR-02 recommended
# default, approval pending). There are no user accounts: a shared secret from the server-side
# environment variable DEMO_WRITE_KEY is sent as `Authorization: Bearer <key>`.
#
#   no key configured on the server → 403 writes_disabled for EVERY write (fail closed, checked first)
#   key configured, request key missing or wrong → 401 unauthorized
#
# The key is compared in constant time, never logged and never echoed.
module WriteKeyAuthentication
  extend ActiveSupport::Concern

  WRITE_KEY_ENV = "DEMO_WRITE_KEY".freeze

  private

  def authenticate_write_key!
    configured = ENV[WRITE_KEY_ENV].to_s
    raise DomainError.new("writes_disabled", "Writes are disabled on this server") if configured.empty?
    return if write_key_matches?(configured)

    response.set_header("WWW-Authenticate", "Bearer")
    raise DomainError.new("unauthorized", "A valid write key is required")
  end

  def write_key_matches?(configured)
    supplied = request.authorization.to_s[/\ABearer (.+)\z/, 1].to_s
    # Hashing first gives equal-length inputs, so the comparison time does not depend on the key.
    ActiveSupport::SecurityUtils.fixed_length_secure_compare(Digest::SHA256.digest(supplied), Digest::SHA256.digest(configured))
  end
end
