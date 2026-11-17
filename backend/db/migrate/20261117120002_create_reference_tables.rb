# Countries, departments and currencies. Codes are varchar(2)/varchar(3) with explicit CHECKs
# rather than char(n), which schema.rb would dump as varchar(n) anyway (DR-21).
class CreateReferenceTables < ActiveRecord::Migration[8.1]
  def change
    create_table :countries, id: false do |t|
      t.string :code, limit: 2, null: false, primary_key: true
      t.string :name, null: false
      t.index :name, unique: true, name: "index_countries_on_name"
      t.check_constraint "char_length(code) = 2", name: "countries_code_length"
      t.check_constraint "code ~ '^[A-Z]+$'", name: "countries_code_format"
    end

    create_table :departments do |t|
      t.string :name, null: false
      t.index :name, unique: true, name: "index_departments_on_name"
    end

    create_table :currencies, id: false do |t|
      t.string :code, limit: 3, null: false, primary_key: true
      t.string :name, null: false
      t.check_constraint "char_length(code) = 3", name: "currencies_code_length"
      t.check_constraint "code ~ '^[A-Z]+$'", name: "currencies_code_format"
    end
  end
end
