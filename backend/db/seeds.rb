# Seeds the deterministic synthetic dataset: exactly 10,000 fictional employees with salary history.
#
#   bin/rails db:seed              seed an empty database (a no-op if this dataset is already present)
#   RESET=1 bin/rails db:seed      delete all employees, salary records and rates, then re-seed
#
# Refuses to run in production unless ALLOW_PRODUCTION_SEED=1. See lib/seeds/demo_dataset.rb.
summary = Seeds::DemoDataset.call(reset: ENV["RESET"] == "1")
puts "Seed complete: #{summary.except(:fingerprint).inspect}"
puts "Fingerprint: #{summary[:fingerprint]}"
