class AlterCalculations < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE Calculations ALTER COLUMN State DROP NOT NULL"
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
