class RenameZTmpCalc < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE z_tmpcalc RENAME TO z_calc_in"
    execute "ALTER INDEX idx_z_tmpcalc RENAME TO idx_z_calc_in"
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
