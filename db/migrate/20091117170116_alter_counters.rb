class AlterCounters < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE Counters ALTER COLUMN InsDate DROP NOT NULL"
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
