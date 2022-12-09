require 'sqlite3'
require 'erb'
require 'pp'
require 'json'
require_relative '../data/known_deck.rb'

class Masaki
  class DeckStore
    include Enumerable
    def initialize
      @db = SQLite3::Database.new(__dir__ + '/../data/deck.db')
      @table = 'deck'
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
      KnownDeck.deck[key] || JSON.parse(fetch(key))
    rescue
      nil
    end

    def []=(key, value)
      store(key, value.to_json)
    end

    def include?(key)
      KnownDeck.deck.include?(key) || (fetch(key) ? true : false)
    end
  
    def each_new_arrive(&blk)
      return enum_for(__method__) unless block_given?
      @db.execute("select id, value from #{@table} order by id") do |row|
        yield(row[0], JSON.parse(row[1]))
      end
    end

    def each(&blk)
      return enum_for(__method__) unless block_given?
      KnownDeck.deck.each(&blk)
      each_new_arrive(&blk)
    end

    def to_rb(fname=nil)
      src =<<EOS
module KnownDeck
  module_function
  def deck; @deck; end
  @deck = 
<%=
self.to_h.pretty_inspect
%>
end
EOS
      rb = ERB.new(src).result(binding)
      return rb unless fname
      File.write(fname, rb)
      rb
    end

    def delete_duplicate
      KnownDeck.deck.each do |k, v|
        @db.execute("delete from #{@table} where id=?", k)
      end
    end

    private
    def fetch(key)
      @db.execute("select value from #{@table} where id=?", key).dig(0,0)
    end

    def store(key, value)
      @db.execute("INSERT OR REPLACE INTO #{@table} (id, value) values (?, ?)", key, value)
    end
  end

  Deck = DeckStore.new
end

if __FILE__ == $0
  case ARGV.shift
  when nil
    puts "usage: [delete|write]"
  when "delete"
    Masaki::Deck.delete_duplicate
  when "write"
    Masaki::Deck.to_rb("known_deck.rb")
  end
end