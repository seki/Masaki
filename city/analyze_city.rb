require_relative '../src/world'
require_relative '../src/masaki-pg'
require 'sqlite3'

module Masaki
  class KVSCache
    def initialize(table, fname="cache.db")
      @db = SQLite3::Database.new(fname)
      @table = table
      setup
    end
    attr_reader :table

    def close
      @db.close
    ensure
      @db = nil
    end

    def setup()
      @db.execute("create table #{table} (id text primary key, value text);")
    rescue
    end

    def fetch(key)
      @db.execute("select value from #{table} where id=?", key).dig(0,0)
    end
  
    def store(key, value)
      @db.execute("INSERT OR REPLACE INTO #{table} (id, value) values (?, ?)", key, value)
    end
  
    def each(&blk)
      @db.execute("select id, value from #{table} order by id") do |row|
        yield(row)
      end
    end
  end

  module Players
    module_function
    def fetch_event_list(last='20221001')
      offset = 0
      list = []
      while true
        chunk = fetch_event_list_1(offset)
        list += chunk['event']
        offset += 20
        break if list[-1]['event_date_params'] <= last
        break if chunk['eventCount'] <= offset
      end
      list
    end
  
    def fetch_event_list_1(offset)
      url = "https://players.pokemon-card.com/event_search?offset=#{offset}&order=4&result_resist=1&event_type[]=3:1&event_type[]=3:2&event_type[]=3:7"
      URI.open(url) do |x|
        return JSON.parse(x.read)
      end
    rescue OpenURI::HTTPError
      pp [:retry_open_uri, key]
      sleep 5
      retry
    end

    def fetch_result_page(key)
      name = "https://players.pokemon-card.com/event_result_detail_search?event_holding_id=#{key}&offset=0"
      URI.open(name) do |x|
        return x.read
      end
    rescue OpenURI::HTTPError
      pp [:retry_open_uri, key]
      sleep 5
      retry
    end
  
    def parse(event)
      date = Date.parse(event.dig('event', 'eventDate', 'date' )).to_s
      event['results'].map do |x|
        deck = x['deck_id']
        deck ? [deck, date] : nil
      end.compact
    end
  end

  module Analyze
    module_function

    def make_deck_subset(decks)
      frozen = MasakiPG::KVS.frozen('deck')
      city_deck = Set.new(decks)
      frozen.find_all {|k, v| city_deck.include?(k) }
    end

    $deck = MasakiPG::KVS.new('deck')
    def import_deck(decks)
      # upload new arrived decks
      MasakiPG::instance.kvs_frozen_world("deck")
      # download from s3
      frozen = MasakiPG::KVS.frozen('deck')
    
      decks.each {|name, date|
        next if frozen.include?(name) || $deck.include?(name)
        p name
        src = DeckDetail.fetch_deck_page(name)
        v = DeckDetail.parse(src)
        $deck[name] = v.to_json
      }
      # upload new arrived decks, again
      MasakiPG::instance.kvs_frozen_world("deck")
    end
  end
end

if __FILE__ == $0
  c = Masaki::KVSCache.new("test")
  c.each {|x| pp x}
  pp c.store("helo", "world")
  c.each {|x| pp x}
  pp c.store("hello", "world")
  c.each {|x| pp x}
  pp c.store("hello", "again")
  c.each {|x| pp x}
  pp c.fetch("hello")
end