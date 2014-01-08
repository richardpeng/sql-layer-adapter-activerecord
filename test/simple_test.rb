$:.unshift File.expand_path(File.join(File.dirname(__FILE__), '../lib'))

require "test/unit"
require 'rubygems'
require 'active_record'

class User < ActiveRecord::Base
  has_one :addr, :class_name => 'Addr'
  def to_s
    return "User(#{@id}), Username: #{@user_name}, Name: #{@first_name} #{@last_name}, #{@admin ? "admin" : "member"}\n" +
      "  Address: #{@addr}\n"
  end
end

class Addr < ActiveRecord::Base
  belongs_to :User
  def to_s
    return "Addr(#{@id}:#{@user_id}) Street: #{@street} City: #{@city} Zip: #{@zip}"
  end
end

class FDBSQLSimpleTest < Test::Unit::TestCase

  def setup()

    ActiveRecord::Base.establish_connection(:adapter  => 'fdbsql',
                                            :database => 'activerecord_unittest',
                                            :host     => 'localhost',
                                            :port     => '15432',
                                            :username => 'test',
                                            :password => '')

    ActiveRecord::Schema.drop_table(User.table_name) rescue nil

    ActiveRecord::Schema.drop_table(Addr.table_name) rescue nil

    ActiveRecord::Schema.define do
      create_table User.table_name do |t|
        t.string :first_name, :limit => 20
        t.string :last_name, :limit => 20
        t.string :email, :limit => 20
        t.string :user_name, :limit => 20
        t.boolean :admin
      end
      create_table(Addr.table_name) do |t|
        t.integer :user_id
        t.string :street, :limit => 20
        t.string :city, :limit => 20
        t.string :zip, :limit => 6
      end
    end
  end


  def test_create_user_records

    john = User.create do |u|
      u.first_name = "John"
      u.last_name = "Doe"
      u.email = "john@doe.fake"
      u.user_name = "johndoe"
      u.admin = true
    end

    assert_not_nil john
    assert_not_nil john.id

    john.create_addr do |a|
      a.street = "123 Oak"
      a.city = "Cambridge"
      a.zip = "02114"
    end

    assert_not_nil john.addr

    jane = User.create do |u|
      u.first_name = "Jane"
      u.last_name = "Doe"
      u.email = "jane@doe.fake"
      u.user_name = "janedoe"
      u.admin = false
    end

    assert_not_nil jane
    assert_not_nil jane.id

    jane.create_addr do |a|
      a.street = "456 Pine"
      a.city = "Boston"
      a.zip = "02118"
    end

    assert_not_nil jane.addr

    assert_equal 2, User.count

    assert_equal 2, Addr.count

    mask = 0
    User.find do |entry|
      case entry.id 
      when john.id
        assert_equal 'John', entry.first_name
        assert_equal 'Doe', entry.last_name
        assert_equal '123 Oak', entry.addr.street
        mask += 1
        nil
      when jane.id
        assert_equal 'Jane', entry.first_name
        assert_equal "Doe", entry.last_name
        assert_equal '456 Pine', entry.addr.street
        mask += 10
        nil
      else
        raise "unknown entry.id: #{entry.id}"
      end
    end

    assert_equal 11, mask

    User.all.each do |entry|
      entry.first_name = entry.first_name.upcase
      entry.last_name = entry.last_name.upcase
      entry.addr.street = entry.addr.street.upcase
      entry.addr.save
      entry.save
    end

    assert_equal 2, User.count

    User.find do |entry|
      case entry.id
      when john.id
        assert_equal 'JOHN', entry.first_name
        assert_equal '123 OAK', entry.addr.street
        nil
      when jane.id
        assert_equal 'JANE', entry.first_name
        assert_equal '456 PINE', entry.addr.street
        nil
      else
        raise 'unknown entry.id'
      end
    end

  end

end
