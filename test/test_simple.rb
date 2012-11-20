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

class AkibanSimpleTest < Test::Unit::TestCase

  def setup()

    ActiveRecord::Base.establish_connection(
                                            :adapter  => 'akiban',
                                            :database => 'activerecord_unittest',
                                            :host     => '127.0.0.1',
                                            :port     => '15432',
                                            :username => 'what',
                                            :password => 'what'
                                           )

    ActiveRecord::Schema.drop_table(User.table_name, :drop_group => true) rescue nil

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
    ActiveRecord::Schema.add_grouping_foreign_key(Addr.table_name, User.table_name, 'user_id')

  end


  def test_create_user_records

    thedude = User.create do |u|
      u.first_name = "Jeff"
      u.last_name = "Lebowski"
      u.email = "thedude@walters.com"
      u.user_name = "thedude"
      u.admin = true
    end

    assert_not_nil thedude
    assert_not_nil thedude.id

    thedude.create_addr do |a|
      a.street = "54 Bum Drive"
      a.city = "LA"
      a.zip = "90987"
    end

    assert_not_nil thedude.addr

    myself = User.create do |u|
      u.first_name = "Padraig"
      u.last_name = "O'Sullivan"
      u.email = "posulliv@akiban.com"
      u.user_name = "posulliv"
      u.admin = false
    end

    assert_not_nil myself
    assert_not_nil myself.id

    myself.create_addr do |a|
      a.street = "inman square"
      a.city = "cambridge"
      a.zip = "02141"
    end

    assert_not_nil myself.addr

    assert_equal 2, User.count

    assert_equal 2, Addr.count

    mask = 0
    User.find do |entry|
      case entry.id 
      when thedude.id
        assert_equal 'Jeff', entry.first_name
        assert_equal 'Lebowski', entry.last_name
        assert_equal '54 Bum Drive', entry.addr.street
        mask += 1
        nil
      when myself.id
        assert_equal 'Padraig', entry.first_name
        assert_equal "O'Sullivan", entry.last_name
        assert_equal 'inman square', entry.addr.street
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
      when thedude.id
        assert_equal 'JEFF', entry.first_name
        assert_equal '54 BUM DRIVE', entry.addr.street
        nil
      when myself.id
        assert_equal 'PADRAIG', entry.first_name
        assert_equal 'INMAN SQUARE', entry.addr.street
        nil
      else
        raise 'unknown entry.id'
      end
    end

  end

end
