class EnhanceService < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE Services ADD Ignore BOOLEAN"
    execute "UPDATE Services SET Ignore = TRUE WHERE Code IN ('03', '04')"
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
