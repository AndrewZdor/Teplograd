class CreateCorrections < ActiveRecord::Migration
  def self.up
    execute "
    CREATE TABLE Corrections
    (
      Id serial NOT NULL,
      ConsumerId integer NOT NULL,
      DateFrom Date NOT NULL,
      Value Number NOT NULL,
      IsIncome Boolean NOT NULL DEFAULT FALSE,
      Rem Citext,
      insertuserid citext DEFAULT CURRENT_USER,
      insertts timestamp without time zone DEFAULT LOCALTIMESTAMP,
      updateuserid citext DEFAULT CURRENT_USER,
      updatets timestamp without time zone DEFAULT LOCALTIMESTAMP,
      revision integer DEFAULT 0,
      CONSTRAINT pk_corrections PRIMARY KEY (id),
      CONSTRAINT fk_corrections_consumers FOREIGN KEY (consumerid)
          REFERENCES consumers (id) MATCH SIMPLE
          ON UPDATE RESTRICT ON DELETE RESTRICT
    )
    WITH (
      OIDS=FALSE
    );
    "

    execute "
    CREATE TRIGGER updusts_corrections
      BEFORE UPDATE
      ON Corrections
      FOR EACH ROW
      EXECUTE PROCEDURE updateusts();"
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
