# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20091203172839) do

  create_table "auditlog", :force => true do |t|
    t.datetime "eventts",                        :null => false
    t.integer  "userid",                         :null => false
    t.integer  "entityid",                       :null => false
    t.integer  "rowid",                          :null => false
    t.text     "fieldvalues"
    t.text     "fieldvaluesfull"
    t.integer  "revision",        :default => 0
  end

  create_table "banks", :id => false, :force => true do |t|
    t.integer  "id",                          :null => false
    t.text     "mfo",                         :null => false
    t.text     "name",                        :null => false
    t.text     "address"
    t.text     "phone"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
  end

  create_table "benefits", :force => true do |t|
    t.integer  "personid",                                       :null => false
    t.integer  "typeid"
    t.boolean  "ismain",                      :default => false, :null => false
    t.text     "doc"
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.integer  "personcount"
  end

  create_table "benefittypes", :force => true do |t|
    t.text     "kfk"
    t.text     "code",                        :null => false
    t.text     "name"
    t.integer  "percent",                     :null => false
    t.date     "datefrom"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
  end

  add_index "benefittypes", ["kfk", "code"], :name => "ux_benefittypes", :unique => true

  create_table "calctemplates", :force => true do |t|
    t.integer  "calctypeid",                                    :null => false
    t.integer  "orderno",                                       :null => false
    t.string   "fieldname",    :limit => nil,                   :null => false
    t.string   "querysql",     :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.boolean  "dorestrict",                  :default => true
  end

  add_index "calctemplates", ["calctypeid", "orderno"], :name => "un_calclockdef_calctyp_ordno", :unique => true
  add_index "calctemplates", ["calctypeid", "orderno"], :name => "un_calclockdefs_calctypeid_orderno", :unique => true

  create_table "calctypes", :force => true do |t|
    t.string   "code",         :limit => nil,                :null => false
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.string   "inputfields",  :limit => nil
    t.string   "inputsql",     :limit => nil
  end

  add_index "calctypes", ["code"], :name => "un_calctypes_code", :unique => true

  create_table "calculations", :force => true do |t|
    t.integer  "calctypeid",                                 :null => false
    t.date     "datefrom",                                   :null => false
    t.date     "dateto",                                     :null => false
    t.string   "state",        :limit => nil
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  add_index "calculations", ["calctypeid", "datefrom"], :name => "un_calcul_calctype_datefrom", :unique => true
  add_index "calculations", ["calctypeid", "datefrom"], :name => "un_calculations_calctype_datefrom", :unique => true

  create_table "cities", :force => true do |t|
    t.text     "name",                        :null => false
    t.integer  "zip"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
    t.date     "insdate"
    t.date     "deldate"
  end

  add_index "cities", ["name"], :name => "ix_cities_nm", :unique => true

  create_table "consumers", :force => true do |t|
    t.string   "code",            :limit => nil
    t.text     "nam",                                           :null => false
    t.string   "name",            :limit => nil
    t.string   "rem",             :limit => nil
    t.text     "taxcode"
    t.text     "ndscode"
    t.text     "ndssvidet"
    t.text     "phone"
    t.string   "address",         :limit => nil
    t.text     "email"
    t.integer  "taxmode",         :limit => 2
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                       :default => 0
    t.date     "insdate"
    t.date     "deldate"
    t.text     "rs"
    t.text     "mfo"
    t.text     "fax"
    t.text     "dirfio"
    t.text     "dirphone"
    t.text     "glavbuhfio"
    t.text     "glavbuhphone"
    t.text     "calcfio"
    t.text     "calcphone"
    t.text     "deliveryaddress"
  end

  add_index "consumers", ["code"], :name => "ux_consumers_code", :unique => true

  create_table "contracts", :force => true do |t|
    t.integer  "consumerid",                  :null => false
    t.text     "code",                        :null => false
    t.date     "datefrom",                    :null => false
    t.date     "dateto"
    t.text     "book"
    t.text     "rem"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
  end

  add_index "contracts", ["consumerid", "code", "datefrom"], :name => "ux_contracts", :unique => true

  create_table "corrections", :force => true do |t|
    t.integer  "consumerid",                      :null => false
    t.date     "datefrom",                        :null => false
    t.decimal  "value",                           :null => false
    t.boolean  "isincome",     :default => false, :null => false
    t.text     "rem"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
  end

  create_table "countcalctypes", :force => true do |t|
    t.string   "code",         :limit => nil
    t.string   "name",         :limit => nil
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.date     "insdate"
    t.date     "deldate"
  end

  add_index "countcalctypes", ["code"], :name => "un_countcalctypes_code", :unique => true

  create_table "countcalculators", :force => true do |t|
    t.string   "code",         :limit => nil
    t.string   "name",         :limit => nil
    t.integer  "calctypeid"
    t.text     "num"
    t.integer  "nodeid",                                         :null => false
    t.boolean  "combined",                    :default => false, :null => false
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.date     "insdate"
    t.date     "deldate"
  end

  add_index "countcalculators", ["code"], :name => "un_countcalculators_code", :unique => true

  create_table "countdata", :force => true do |t|
    t.integer  "counterid",                                  :null => false
    t.date     "datefrom",                                   :null => false
    t.decimal  "value",                                      :null => false
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.date     "dateto",                                     :null => false
  end

  add_index "countdata", ["id", "counterid", "datefrom"], :name => "un_countdata_id_count_datfrom", :unique => true
  add_index "countdata", ["id", "counterid", "datefrom"], :name => "un_countdata_id_counterid_datefrom", :unique => true

  create_table "counters", :force => true do |t|
    t.string   "code",         :limit => nil
    t.string   "name",         :limit => nil
    t.integer  "calcid"
    t.integer  "serviceid",                                  :null => false
    t.integer  "objectid"
    t.integer  "pprtypeid"
    t.text     "pprnum"
    t.integer  "tsptypeid"
    t.text     "tspnum"
    t.date     "regdate"
    t.date     "unregdate"
    t.date     "checkdate"
    t.string   "rem",          :limit => nil
    t.date     "deldate"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.date     "insdate"
    t.integer  "pprtypeid2"
    t.text     "pprnum2"
    t.integer  "tsptypeid2"
    t.text     "tspnum2"
  end

  add_index "counters", ["code"], :name => "un_counters_code", :unique => true

  create_table "countnodes", :force => true do |t|
    t.string   "code",          :limit => nil
    t.string   "name",          :limit => nil
    t.string   "rem",           :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                     :default => 0
    t.integer  "ownerid"
    t.integer  "houseobjectid"
    t.date     "insdate"
    t.date     "deldate"
  end

  add_index "countnodes", ["code"], :name => "un_countnodes_code", :unique => true

  create_table "countpprtypes", :force => true do |t|
    t.string   "code",         :limit => nil
    t.string   "name",         :limit => nil
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.date     "insdate"
    t.date     "deldate"
  end

  add_index "countpprtypes", ["code"], :name => "un_countpprtypes_code", :unique => true

  create_table "counttsptypes", :force => true do |t|
    t.string   "code",         :limit => nil
    t.string   "name",         :limit => nil
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  add_index "counttsptypes", ["code"], :name => "un_counttsptypes_code"

  create_table "departments", :force => true do |t|
    t.text     "code",                                   :null => false
    t.text     "name"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
    t.date     "deldate"
    t.date     "insdate",      :default => '1900-01-01'
  end

  add_index "departments", ["code"], :name => "un_departments_code", :unique => true

  create_table "dictionary", :force => true do |t|
    t.text     "languagecode",                               :null => false
    t.string   "code",         :limit => nil,                :null => false
    t.string   "name",         :limit => nil,                :null => false
    t.string   "names",        :limit => nil
    t.string   "abbr",         :limit => nil
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  add_index "dictionary", ["languagecode", "code"], :name => "un_dictionary_langcode_code", :unique => true

  create_table "entities", :force => true do |t|
    t.text     "code",                                                :null => false
    t.text     "rem"
    t.text     "decorator"
    t.text     "orderby"
    t.integer  "table_id_"
    t.string   "lookupcategory",    :limit => nil
    t.integer  "priority"
    t.string   "type",              :limit => nil,                    :null => false
    t.string   "validateproc",      :limit => nil
    t.string   "updateproc",        :limit => nil
    t.integer  "revisionthreshold",                :default => 1000
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                         :default => 0
    t.integer  "lookuphierarchyid"
    t.boolean  "istranslatable",                   :default => false, :null => false
    t.string   "uniquefields",      :limit => nil
    t.string   "rm_mask",           :limit => 16
  end

  add_index "entities", ["lookupcategory", "priority"], :name => "un_entities_lookcategory_prioty", :unique => true
  add_index "entities", ["lookupcategory", "priority"], :name => "un_entities_lookupcategory_priority", :unique => true

  create_table "entityproperties", :force => true do |t|
    t.integer  "entityid"
    t.integer  "orderno",           :limit => 2
    t.integer  "refentityid"
    t.string   "datatype",          :limit => nil
    t.integer  "datalength",        :limit => 2
    t.boolean  "mandatory",                        :default => false, :null => false
    t.boolean  "istemporal",                       :default => false, :null => false
    t.string   "code",              :limit => nil
    t.string   "rem",               :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                         :default => 0
    t.string   "propgroup",         :limit => nil
    t.string   "validationsql",     :limit => nil
    t.string   "retrievesql",       :limit => nil
    t.string   "editable",          :limit => nil
    t.boolean  "donumsort",                        :default => false, :null => false
    t.integer  "lookuphierarchyid"
  end

  add_index "entityproperties", ["entityid", "code"], :name => "un_entitypropert_entityid_code", :unique => true
  add_index "entityproperties", ["entityid", "code"], :name => "un_entityproperties_entityid_code", :unique => true

  create_table "entityvalidation", :force => true do |t|
    t.integer "entityid",                 :null => false
    t.string  "code",      :limit => nil, :null => false
    t.string  "checkmode", :limit => nil, :null => false
    t.string  "rulesql",   :limit => nil, :null => false
    t.string  "errorcode", :limit => nil, :null => false
    t.string  "rem",       :limit => nil
  end

  add_index "entityvalidation", ["entityid", "code"], :name => "un_entityvalidation_entityid_code", :unique => true

  create_table "entrances", :force => true do |t|
    t.integer  "houseobjectid",                               :null => false
    t.integer  "num",           :limit => 2,                  :null => false
    t.string   "code",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                     :default => 0
  end

  create_table "errors", :id => false, :force => true do |t|
    t.string "code",        :limit => nil, :null => false
    t.string "state",       :limit => nil, :null => false
    t.string "legacystate", :limit => nil
    t.string "rem",         :limit => nil
  end

  add_index "errors", ["legacystate"], :name => "un_errors_legacystate"
  add_index "errors", ["state"], :name => "un_errors_state"

  create_table "eventlog", :force => true do |t|
    t.datetime "ts"
    t.integer  "userid"
    t.text     "sqlstate"
    t.text     "sqlerrm"
    t.text     "data"
  end

  create_table "formcontrols", :force => true do |t|
    t.integer  "formid",                                       :null => false
    t.integer  "orderno",       :limit => 2,                   :null => false
    t.integer  "column_id_"
    t.integer  "entityid",                                     :null => false
    t.text     "fieldname",                                    :null => false
    t.boolean  "iseditable",                 :default => true, :null => false
    t.integer  "controltypeid"
    t.text     "style"
    t.text     "misc"
    t.text     "rem"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                   :default => 0
  end

  create_table "forms", :force => true do |t|
    t.text     "code",                        :null => false
    t.text     "name",                        :null => false
    t.text     "rem"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
  end

  create_table "groups", :force => true do |t|
    t.string   "code",         :limit => nil
    t.string   "rem",          :limit => nil
    t.boolean  "isadmin",                     :default => false, :null => false
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  add_index "groups", ["code"], :name => "un_groups_code", :unique => true

  create_table "hierarchies", :force => true do |t|
    t.text     "code",                                       :null => false
    t.integer  "priority",     :limit => 2
    t.text     "rem"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.string   "type",         :limit => nil
    t.string   "rm_mask",      :limit => 16
  end

  create_table "hierarchyfolders", :force => true do |t|
    t.integer  "entityid",                                        :null => false
    t.text     "code"
    t.string   "criteriasql",    :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                      :default => 0
    t.string   "type",           :limit => nil,                   :null => false
    t.string   "hint",           :limit => nil
    t.string   "parentfield",    :limit => nil
    t.string   "childfield",     :limit => nil
    t.integer  "priority"
    t.integer  "hierarchyid",                                     :null => false
    t.integer  "parententityid",                                  :null => false
    t.string   "action",         :limit => nil
    t.boolean  "isselectable",                  :default => true, :null => false
    t.string   "rm_mask",        :limit => 16
  end

  add_index "hierarchyfolders", ["entityid", "code", "type", "hierarchyid", "parententityid"], :name => "un_hierarfold_hier_parid_enid_typ", :unique => true
  add_index "hierarchyfolders", ["hierarchyid", "parententityid", "entityid", "code", "type"], :name => "un_hierarchyfolders_hierarchyid_parententityid_entityid_type", :unique => true

  create_table "houseowners", :force => true do |t|
    t.date     "datefrom"
    t.integer  "houseobjectid",                               :null => false
    t.integer  "consumerid",                                  :null => false
    t.decimal  "area"
    t.string   "flatrange",     :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                     :default => 0
  end

  add_index "houseowners", ["consumerid"], :name => "ix_houseowns_houseid_consumerid", :unique => true

  create_table "languages", :id => false, :force => true do |t|
    t.text     "code",                                       :null => false
    t.string   "name",         :limit => nil,                :null => false
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  create_table "objectcapacities", :force => true do |t|
    t.integer  "objectid",                    :null => false
    t.date     "datefrom",                    :null => false
    t.integer  "serviceid",                   :null => false
    t.decimal  "value1"
    t.decimal  "value2"
    t.decimal  "value3"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
    t.decimal  "counterpart"
    t.integer  "contractid"
    t.text     "rem"
  end

  add_index "objectcapacities", ["datefrom", "objectid", "serviceid", "contractid"], :name => "ux_objectcapacities", :unique => true

  create_table "objectproperties", :force => true do |t|
    t.integer  "objectid"
    t.integer  "propertyid",                                            :null => false
    t.date     "datefrom",                    :default => '1900-01-01', :null => false
    t.string   "value",        :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.integer  "rowid"
  end

  add_index "objectproperties", ["objectid", "propertyid", "datefrom"], :name => "un_objectprop_objid_prop_datfrom", :unique => true
  add_index "objectproperties", ["objectid", "propertyid", "datefrom"], :name => "un_objectproperties_objectid_propertyid_datefrom", :unique => true
  add_index "objectproperties", ["propertyid", "datefrom", "rowid"], :name => "un_objectprop_rowid_prop_datfrom", :unique => true
  add_index "objectproperties", ["propertyid", "value"], :name => "ix_objectprop_proprtyid_value"
  add_index "objectproperties", ["propertyid", "value"], :name => "ix_objectproperties_proprtyid_value"
  add_index "objectproperties", ["rowid", "propertyid", "datefrom"], :name => "un_objectproperties_rowid_propertyid_datefrom", :unique => true

  create_table "objects", :force => true do |t|
    t.integer  "entityid",                                   :null => false
    t.string   "code",         :limit => nil,                :null => false
    t.string   "name",         :limit => nil
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.date     "deldate"
    t.date     "insdate",                                    :null => false
    t.integer  "oldid"
  end

  add_index "objects", ["entityid", "code"], :name => "ix_objects_entityid_code"

  create_table "persons", :force => true do |t|
    t.string   "lastname",     :limit => nil,                    :null => false
    t.string   "firstname",    :limit => nil
    t.string   "middlename",   :limit => nil
    t.text     "inn"
    t.integer  "objectid",                                       :null => false
    t.integer  "gekid"
    t.integer  "account"
    t.text     "passport"
    t.date     "birthdate"
    t.boolean  "ismain",                      :default => false, :null => false
    t.date     "excludedate"
    t.text     "cardnum"
    t.text     "filenum"
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  add_index "persons", ["gekid", "account"], :name => "ux_persons_gekid_account", :unique => true

  create_table "prefs", :force => true do |t|
    t.string   "code",         :limit => nil,                :null => false
    t.string   "datatype",     :limit => nil,                :null => false
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.string   "type",         :limit => nil,                :null => false
  end

  add_index "prefs", ["code"], :name => "un_prefs_code", :unique => true

  create_table "prefvalues", :force => true do |t|
    t.integer  "prefid",                                     :null => false
    t.integer  "userid"
    t.integer  "sessionid"
    t.date     "datefrom"
    t.string   "value",        :limit => nil,                :null => false
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  create_table "regions", :force => true do |t|
    t.text     "code",                        :null => false
    t.text     "name"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
    t.date     "insdate"
    t.date     "deldate"
  end

  add_index "regions", ["code"], :name => "un_regions_code", :unique => true

  create_table "reports", :force => true do |t|
    t.string   "code",         :limit => nil,                :null => false
    t.integer  "calctypeid"
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.string   "reportsql",    :limit => nil
    t.string   "rm_mask",      :limit => 16
    t.text     "jrxml"
  end

  add_index "reports", ["code"], :name => "un_reports_code", :unique => true

  create_table "rms", :force => true do |t|
    t.text     "code",                        :null => false
    t.text     "name",                        :null => false
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
  end

  create_table "servicelog", :force => true do |t|
    t.integer  "objectid"
    t.date     "datefrom"
    t.integer  "serviceid"
    t.boolean  "state",                                      :null => false
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  create_table "services", :force => true do |t|
    t.string   "code",         :limit => nil
    t.string   "name",         :limit => nil
    t.string   "value1",       :limit => nil
    t.string   "value2",       :limit => nil
    t.string   "value3",       :limit => nil
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.date     "insdate"
    t.date     "deldate"
    t.text     "benefitcode"
    t.text     "benefitname"
    t.boolean  "ignore"
  end

  create_table "streets", :force => true do |t|
    t.integer  "cityid",                      :null => false
    t.integer  "streettypeid"
    t.text     "code"
    t.text     "name",                        :null => false
    t.text     "spec"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
    t.date     "insdate"
    t.date     "deldate"
  end

  add_index "streets", ["code"], :name => "ix_streets_code", :unique => true
  add_index "streets", ["streettypeid", "name", "spec"], :name => "ix_streets", :unique => true

  create_table "streettypes", :force => true do |t|
    t.text     "code",                        :null => false
    t.text     "name"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
    t.date     "insdate"
    t.date     "deldate"
  end

  add_index "streettypes", ["code"], :name => "ix_streettypes_code", :unique => true
  add_index "streettypes", ["name"], :name => "ix_streettypes_nm", :unique => true

  create_table "tariffs", :force => true do |t|
    t.string   "code",         :limit => nil
    t.string   "name",         :limit => nil,                :null => false
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.date     "insdate"
    t.date     "deldate"
  end

  add_index "tariffs", ["code"], :name => "un_tariffs_code", :unique => true
  add_index "tariffs", ["name"], :name => "un_tariffs_name", :unique => true

  create_table "tariffvalues", :force => true do |t|
    t.date     "datefrom",                                   :null => false
    t.integer  "tariffid",                                   :null => false
    t.integer  "serviceid",                                  :null => false
    t.decimal  "value1"
    t.decimal  "value2"
    t.decimal  "value3"
    t.string   "rem",          :limit => nil
    t.string   "insertuserid", :limit => nil
    t.datetime "insertts"
    t.string   "updateuserid", :limit => nil
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  add_index "tariffvalues", ["tariffid", "serviceid", "datefrom"], :name => "un_tariffvalues_tariffid_serviceid_datefrom", :unique => true

  create_table "tasks", :force => true do |t|
    t.integer  "typeid"
    t.integer  "subjectid"
    t.string   "description",  :limit => nil
    t.string   "state",        :limit => nil
    t.integer  "progress",                    :default => -1
    t.string   "progressrem",  :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  add_index "tasks", ["insertts"], :name => "un_tasks_insertts", :unique => true

  create_table "tasktypes", :force => true do |t|
    t.string   "code",         :limit => nil,                :null => false
    t.integer  "progressmax"
    t.string   "rem",          :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
    t.integer  "entityid",                                   :null => false
  end

  add_index "tasktypes", ["code"], :name => "un_tasktypes_code", :unique => true

  create_table "typemapping", :id => false, :force => true do |t|
    t.text "sqltype",     :null => false
    t.text "javasqltype"
    t.text "typegroup"
  end

  create_table "usergroups", :force => true do |t|
    t.integer "userid",                    :null => false
    t.integer "groupid",                   :null => false
    t.boolean "enabled", :default => true, :null => false
  end

  add_index "usergroups", ["userid", "groupid"], :name => "un_usergroups_userid_groupid", :unique => true

  create_table "users", :force => true do |t|
    t.string   "name",         :limit => nil
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                    :default => 0
  end

  create_table "z_calc_1__rpt_main_invoice", :id => false, :force => true do |t|
    t.integer "invoiceno"
    t.integer "consumerid"
    t.text    "name"
    t.text    "taxcode"
    t.text    "deliveryaddress"
    t.text    "address"
    t.text    "placecode"
    t.text    "servicename"
    t.decimal "capacity"
    t.decimal "tariff"
    t.decimal "sum_days"
    t.decimal "sum_money"
    t.decimal "sum_money_vat"
  end

  create_table "z_calc_1_in", :id => false, :force => true do |t|
    t.integer "objectid"
    t.integer "serviceid"
    t.integer "tmlid"
    t.integer "rowid"
    t.date    "datefrom"
    t.date    "dateto"
    t.text    "value"
  end

  add_index "z_calc_1_in", ["objectid", "serviceid", "tmlid", "datefrom"], :name => "idx_z_calc_1_in"

  create_table "z_calc_1_obj", :id => false, :force => true do |t|
    t.integer "objectid"
    t.integer "serviceid"
  end

  add_index "z_calc_1_obj", ["objectid", "serviceid"], :name => "idx_z_calc_1_obj"

  create_table "z_calc_1_out", :id => false, :force => true do |t|
    t.integer "objectid"
    t.integer "serviceid"
    t.integer "payerid"
    t.date    "datefrom"
    t.date    "dateto"
    t.decimal "days"
    t.decimal "value"
    t.decimal "tariff"
    t.decimal "money"
    t.string  "rem",       :limit => nil
  end

  add_index "z_calc_1_out", ["objectid", "serviceid"], :name => "idx_z_calc_1_out"

  create_table "z_calc_in", :id => false, :force => true do |t|
    t.integer "objectid"
    t.integer "serviceid"
    t.integer "tmlid"
    t.integer "rowid"
    t.date    "datefrom"
    t.date    "dateto"
    t.text    "value"
  end

  add_index "z_calc_in", ["objectid", "serviceid", "tmlid", "datefrom"], :name => "idx_z_calc_in"

  create_table "z_calc_obj", :id => false, :force => true do |t|
    t.integer "objectid"
    t.integer "serviceid"
  end

  add_index "z_calc_obj", ["objectid", "serviceid"], :name => "idx_z_calc_obj"

  create_table "z_calc_out", :id => false, :force => true do |t|
    t.integer "objectid"
    t.integer "serviceid"
    t.integer "payerid"
    t.date    "datefrom"
    t.date    "dateto"
    t.decimal "days"
    t.decimal "value"
    t.decimal "tariff"
    t.decimal "money"
    t.string  "rem",       :limit => nil
  end

  add_index "z_calc_out", ["objectid", "payerid", "serviceid", "datefrom"], :name => "un_z_calc_1_out", :unique => true

  create_table "z_ext_dept", :id => false, :force => true do |t|
    t.text     "dept"
    t.text     "dept_nm"
    t.integer  "regionid"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",     :default => 0
  end

  add_index "z_ext_dept", ["dept"], :name => "ind_z_ext_dept_2"
  add_index "z_ext_dept", ["regionid"], :name => "ind_z_ext_dept_1"

  create_table "z_ext_kotel", :id => false, :force => true do |t|
    t.text     "vid_kot"
    t.text     "n_kot_cod"
    t.text     "kot_cod"
    t.text     "trp_nm"
    t.decimal  "ot_pl",        :precision => 30, :scale => 6
    t.decimal  "ot_gkal",      :precision => 30, :scale => 6
    t.decimal  "g_w_cel",      :precision => 30, :scale => 6
    t.decimal  "g_w_kubm",     :precision => 30, :scale => 6
    t.decimal  "g_w_gkal",     :precision => 30, :scale => 6
    t.decimal  "ot_ventil",    :precision => 30, :scale => 6
    t.decimal  "ot_texnol",    :precision => 30, :scale => 6
    t.text     "mark"
    t.integer  "objectid"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                                    :default => 0
  end

  create_table "z_ext_lgoty", :force => true do |t|
    t.integer "a",         :limit => 5,  :precision => 5,  :scale => 0
    t.text    "fio"
    t.text    "obj_cod"
    t.text    "p_cod"
    t.text    "gsk"
    t.integer "g_w_cel",   :limit => 7,  :precision => 7,  :scale => 0
    t.decimal "ot_pl",                   :precision => 8,  :scale => 1
    t.integer "procent",   :limit => 3,  :precision => 3,  :scale => 0
    t.text    "cod_tar"
    t.text    "com"
    t.text    "lgotcod"
    t.text    "god_rogd"
    t.text    "mark"
    t.text    "kat"
    t.text    "identific"
    t.text    "flat"
    t.text    "dept"
    t.text    "countot"
    t.text    "countgw"
    t.decimal "plosh",                   :precision => 10, :scale => 2
    t.integer "chelovek",  :limit => 10, :precision => 10, :scale => 0
    t.text    "codnov"
    t.text    "kfk"
    t.integer "placeid"
    t.integer "personid"
  end

  create_table "z_ext_objects", :id => false, :force => true do |t|
    t.text     "kn"
    t.decimal  "n_obj",        :precision => 30, :scale => 6
    t.text     "vid_rs"
    t.text     "vid_potr"
    t.text     "n_kor"
    t.text     "kor"
    t.text     "dop_pr"
    t.decimal  "n_dom",        :precision => 30, :scale => 6
    t.text     "adres_vid"
    t.text     "adres_cod"
    t.decimal  "kod_ul",       :precision => 30, :scale => 6
    t.text     "adres"
    t.decimal  "a",            :precision => 30, :scale => 6
    t.text     "obj_adr"
    t.text     "p_cod"
    t.text     "obj_cod"
    t.text     "snat"
    t.date     "date_do"
    t.text     "reg_cod"
    t.text     "dept"
    t.text     "cod_tar"
    t.text     "kot_cod"
    t.decimal  "ot_pl",        :precision => 30, :scale => 6
    t.decimal  "ot_gkal",      :precision => 30, :scale => 6
    t.decimal  "g_w_cel",      :precision => 30, :scale => 6
    t.decimal  "g_w_kubm",     :precision => 30, :scale => 6
    t.decimal  "g_w_gkal",     :precision => 30, :scale => 6
    t.decimal  "ot_ventil",    :precision => 30, :scale => 6
    t.decimal  "ot_texnol",    :precision => 30, :scale => 6
    t.text     "wed"
    t.text     "gek"
    t.text     "trp_cod"
    t.decimal  "pl_sprav",     :precision => 30, :scale => 6
    t.text     "weight"
    t.text     "vid_th"
    t.decimal  "gkal",         :precision => 30, :scale => 6
    t.decimal  "bank",         :precision => 30, :scale => 6
    t.decimal  "bart",         :precision => 30, :scale => 6
    t.decimal  "vz",           :precision => 30, :scale => 6
    t.text     "n_cod"
    t.text     "trp_cod1"
    t.text     "s_pcod"
    t.text     "name"
    t.text     "dog"
    t.decimal  "n_23",         :precision => 30, :scale => 6
    t.text     "vid_p"
    t.text     "kot_name"
    t.text     "vvod"
    t.text     "mark"
    t.integer  "streettypeid"
    t.integer  "streetid"
    t.integer  "houseid"
    t.integer  "placeid"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                                    :default => 0
  end

  add_index "z_ext_objects", ["adres"], :name => "ind_z_ext_objects_5"
  add_index "z_ext_objects", ["adres_vid"], :name => "ind_z_ext_objects_4"
  add_index "z_ext_objects", ["dept"], :name => "ind_z_ext_objects_6"
  add_index "z_ext_objects", ["dop_pr"], :name => "ind_z_ext_objects_9"
  add_index "z_ext_objects", ["houseid"], :name => "ind_z_ext_objects_3"
  add_index "z_ext_objects", ["n_dom"], :name => "ind_z_ext_objects_8"
  add_index "z_ext_objects", ["reg_cod"], :name => "ind_z_ext_objects_7"
  add_index "z_ext_objects", ["streetid"], :name => "ind_z_ext_objects_2"
  add_index "z_ext_objects", ["streettypeid"], :name => "ind_z_ext_objects_1"

  create_table "z_ext_region", :id => false, :force => true do |t|
    t.text     "reg_cod"
    t.text     "reg_nm"
    t.decimal  "ot_pl",        :precision => 30, :scale => 6
    t.decimal  "ot_gkal",      :precision => 30, :scale => 6
    t.decimal  "g_w_cel",      :precision => 30, :scale => 6
    t.decimal  "g_w_kubm",     :precision => 30, :scale => 6
    t.decimal  "g_w_gkal",     :precision => 30, :scale => 6
    t.decimal  "ot_ventil",    :precision => 30, :scale => 6
    t.decimal  "ot_texnol",    :precision => 30, :scale => 6
    t.text     "mark"
    t.integer  "departmentid"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                                    :default => 0
  end

  add_index "z_ext_region", ["departmentid"], :name => "ind_z_ext_region_1"

  create_table "z_ext_splat", :id => false, :force => true do |t|
    t.text     "kn"
    t.text     "kn1"
    t.text     "p_cod"
    t.text     "vr"
    t.text     "p_nm"
    t.text     "snat"
    t.date     "date_do"
    t.text     "vid_p"
    t.text     "rs"
    t.text     "mfo"
    t.text     "kodplatel"
    t.text     "dogovor"
    t.decimal  "ot_pl",        :precision => 30, :scale => 6
    t.decimal  "ot_gkal",      :precision => 30, :scale => 6
    t.decimal  "g_w_cel",      :precision => 30, :scale => 6
    t.decimal  "g_w_kubm",     :precision => 30, :scale => 6
    t.decimal  "g_w_gkal",     :precision => 30, :scale => 6
    t.decimal  "ot_ventil",    :precision => 30, :scale => 6
    t.decimal  "ot_texnol",    :precision => 30, :scale => 6
    t.text     "dept"
    t.text     "wed"
    t.text     "mark"
    t.text     "gorod"
    t.text     "adress"
    t.text     "ylica"
    t.text     "indeks"
    t.text     "faks"
    t.text     "fio_dir"
    t.text     "tel_dir"
    t.text     "fio_glbuh"
    t.text     "tel_glbuh"
    t.text     "fio_rasch"
    t.text     "tel_rasch"
    t.text     "k_nalog"
    t.text     "n_nalog"
    t.decimal  "ck",           :precision => 30, :scale => 6
    t.decimal  "gkal",         :precision => 30, :scale => 6
    t.text     "nalog"
    t.decimal  "LIMIT",        :precision => 30, :scale => 6
    t.text     "osn_limit"
    t.text     "pokup"
    t.text     "old_pcod"
    t.text     "adress1"
    t.text     "s_pcod"
    t.text     "zd"
    t.text     "ar"
    t.text     "rem_f1"
    t.text     "h_in_n_f1"
    t.integer  "consumerid"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                                    :default => 0
  end

  add_index "z_ext_splat", ["consumerid"], :name => "ind_z_ext_splat_1"

  create_table "z_ext_streets_ispolkom", :id => false, :force => true do |t|
    t.decimal  "code",         :precision => 30, :scale => 6
    t.text     "type"
    t.text     "name"
    t.integer  "streettypeid"
    t.integer  "streetid"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                                    :default => 0
  end

  add_index "z_ext_streets_ispolkom", ["streetid"], :name => "ind_z_ext_streets_ispolkom_2"
  add_index "z_ext_streets_ispolkom", ["streettypeid"], :name => "ind_z_ext_streets_ispolkom_1"

  create_table "z_ext_tarif", :id => false, :force => true do |t|
    t.string   "cod_tar",      :limit => nil
    t.string   "t_nm",         :limit => nil
    t.string   "t_ot_mkb",     :limit => nil
    t.string   "t_ot_gkal",    :limit => nil
    t.string   "t_gw_cel",     :limit => nil
    t.string   "t_gw_gkal",    :limit => nil
    t.string   "t_gw_kubm",    :limit => nil
    t.string   "t_xw_cel",     :limit => nil
    t.string   "t_xw_kubm",    :limit => nil
    t.string   "t_tex_gkal",   :limit => nil
    t.string   "t_ven_gkal",   :limit => nil
    t.integer  "tariffid"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
  end

  create_table "z_ext_trp", :id => false, :force => true do |t|
    t.text     "trp_cod"
    t.text     "trp_cod1"
    t.text     "trp_nm"
    t.decimal  "ot_pl",        :precision => 30, :scale => 6
    t.decimal  "ot_gkal",      :precision => 30, :scale => 6
    t.decimal  "g_w_cel",      :precision => 30, :scale => 6
    t.decimal  "g_w_kubm",     :precision => 30, :scale => 6
    t.decimal  "g_w_gkal",     :precision => 30, :scale => 6
    t.decimal  "ot_ventil",    :precision => 30, :scale => 6
    t.decimal  "ot_texnol",    :precision => 30, :scale => 6
    t.text     "mark"
    t.integer  "objectid"
    t.text     "insertuserid"
    t.datetime "insertts"
    t.text     "updateuserid"
    t.datetime "updatets"
    t.integer  "revision",                                    :default => 0
  end

end
