ActiveRecord::Schema.define do

  create_table :fk_test_has_fk, :force => true do |t|
    t.integer :fk_id, :null => false
  end

  create_table :fk_test_has_pk, :force => true do |t|
  end

end
