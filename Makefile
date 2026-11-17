.PHONY: setup backend-check frontend-check check

# One-time (and after dependency changes) setup for both apps.
setup:
	cd backend && bundle install && bin/rails db:prepare
	cd frontend && npm ci

# bin/ci: setup, RuboCop, bundler-audit (needs network), Brakeman, RSpec.
backend-check:
	cd backend && bin/ci

frontend-check:
	cd frontend && npm run typecheck && npm run lint && npm test && npm run build

check: backend-check frontend-check
