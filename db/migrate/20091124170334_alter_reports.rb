class AlterReports < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE Reports ADD COLUMN JrXml TEXT"
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
