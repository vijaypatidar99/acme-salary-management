# Loaded for every run via .rspec. Keep it light: Rails itself is loaded by rails_helper.
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    # Prevents stubbing methods that do not exist on the real object.
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Use only the non-monkey-patched syntax (RSpec.describe, not bare describe).
  config.disable_monkey_patching!

  # Tests must not depend on order: run in random order. Reproduce with --seed N.
  config.order = :random
  Kernel.srand config.seed

  # The full 10,000-employee seed spec takes seconds: run it with FULL_SEED=1 bundle exec rspec --tag full_seed.
  config.filter_run_excluding :full_seed unless ENV["FULL_SEED"]

  # Tag an example or group with :focus to run only it; runs everything when nothing is tagged.
  config.filter_run_when_matching :focus
end
