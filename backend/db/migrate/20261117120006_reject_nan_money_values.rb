# PostgreSQL orders numeric NaN above finite numbers, so a > 0 CHECK alone accepts it.
# Keep the existing positive-value rules while preventing non-money values through direct SQL.
class RejectNanMoneyValues < ActiveRecord::Migration[8.1]
  def change
    [ [ :salary_records, :amount ], [ :salary_records, :fx_rate ], [ :exchange_rates, :rate ] ].each do |table, column|
      name = "#{table}_#{column}_positive"
      remove_check_constraint table, "#{column} > 0", name: name
      add_check_constraint table, "#{column} > 0 AND #{column} <> 'NaN'::numeric", name: name
    end
  end
end
