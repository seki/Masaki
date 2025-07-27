require 'sqlite3'
require 'erb'
require 'pp'
require 'json'

class Masaki
  class CardPageStore
    include Enumerable
    def initialize
      @db = SQLite3::Database.new(__dir__ + '/../data/card_page.db')
      @table = 'card_page'
      setup
    end

    def close
      @db.close
    ensure
      @db = nil
    end

    def setup()
      @db.execute("create table #{@table} (id text primary key, value text);")
    rescue
    end

    def [](key)
      fetch(key)
    rescue
      nil
    end

    def []=(key, value)
      store(key, value)
    end

    def include?(key)
      (fetch(key) ? true : false)
    end

    private
    def fetch(key)
      @db.execute("select value from #{@table} where id=?", key).dig(0,0)
    end

    def store(key, value)
      @db.execute("INSERT OR REPLACE INTO #{@table} (id, value) values (:key, :value)", :key => key, :value => value)
    end
  end
  CardPage = CardPageStore.new
end

if __FILE__ == $0
  require_relative 'masaki-pg'
  pg = MasakiPG::KVS.new('card_page')
  pg.each do |k, v|
    Masaki::CardPage[k] = v
    puts k
  end
end