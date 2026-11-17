# Lookup source for FX rates. 1 unit of from_currency = rate units of to_currency (only USD targets are used).
class CreateExchangeRates < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_rates do |t|
      t.string :from_currency, limit: 3, null: false
      t.string :to_currency, limit: 3, null: false
      t.decimal :rate, precision: 18, scale: 8, null: false
      t.date :effective_on, null: false
      t.datetime :created_at, null: false

      t.index %i[from_currency to_currency effective_on], unique: true, name: "index_exchange_rates_lookup"
      t.check_constraint "rate > 0", name: "exchange_rates_rate_positive"
      t.check_constraint "from_currency <> to_currency OR rate = 1", name: "exchange_rates_identity_rate"
    end

    add_foreign_key :exchange_rates, :currencies, column: :from_currency, primary_key: :code,
                                                  name: "fk_exchange_rates_from_currency"
    add_foreign_key :exchange_rates, :currencies, column: :to_currency, primary_key: :code,
                                                  name: "fk_exchange_rates_to_currency"
  end
end
