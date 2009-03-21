ActiveRecord::Schema.define(:version => 20090317164830) do
  create_table "androids", :force => true do |t|
    t.string   "name"
    t.integer  "owner_id"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "people", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
end