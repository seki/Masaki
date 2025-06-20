require_relative '../src/world'
require_relative '../src/store-deck'
require_relative '../src/store-meta'
require_relative 'deck_name'
require 'sqlite3'

class Masaki
  class KVSCache
    include Enumerable
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
      @db.execute("INSERT OR REPLACE INTO #{table} (id, value) values (:key, :value)", :key => key, :value => value)
    end
  
    def each(&blk)
      return enum_for(__method__) unless block_given?
      @db.execute("select id, value from #{table} order by id") do |row|
        yield(row)
      end
    end
  end

  module Players
    module_function
    def fetch_event_list(last='20221001')
      db = Masaki::KVSCache.new('city_event')
      offset = 0
      list = []
      while true
        chunk = fetch_event_list_1(offset)
        list += chunk['event']
        offset += 20
        break if list[-1]['event_date_params'] <= last
        break if chunk['eventCount'] <= offset
        break unless fetch_event_store(db, chunk)
      end
      fetch_event_from_cache(db)
    ensure
      db.close
    end

    def fetch_event_store(db, chunk)
      found = false
      chunk['event'].each do |event|
        unless db.fetch(event['event_holding_id'])
          db.store(event['event_holding_id'], event.to_json)
          found = true
        end
      end
      found
    end

    def fetch_event_from_cache(db)
      db.map do |row|
        JSON.parse(row[1])
      end
    end
  
    def fetch_event_list_1(offset)
      url = "https://players.pokemon-card.com/event_search?offset=#{offset}&order=4&result_resist=1&event_type[]=3:1&event_type[]=3:2&event_type[]=3:7"
      URI.open(url) do |x|
        return JSON.parse(x.read)
      end
    rescue OpenURI::HTTPError
      pp [:retry_open_uri, :fetch_event_list_1, key]
      sleep 5
      retry
    end

    def fetch_result_page(key)
      name = "https://players.pokemon-card.com/event_result_detail_search?event_holding_id=#{key}&offset=0"
      URI.open(name) do |x|
        return x.read
      end
    rescue OpenURI::HTTPError
      pp [:retry_open_uri, :fetch_result_page, key, $!]
      return nil if $!.message == '404 Not Found'
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
    def import_deck(decks)
      decks.each {|name, date|
        Masaki::Meta.referer_city_store(name, date)
        Masaki::Meta.referer_all_store(name, date)
        next if Masaki::Deck.include?(name)
        src = DeckDetail.fetch_deck_page(name)
        v = DeckDetail.parse(src)
        Masaki::Deck[name] = v
      }
    end

    def last_month_friday # 金曜日始まり
      d = Date.today - 35
      d - d.wday + 5
      Date.parse('2025-05-02')
    end

    def weekly_analyze(world, deck_and_date)
      origin = last_month_friday
      weekly = deck_and_date.sort_by {|x| x[1]}.chunk {|x|
        (Date.parse(x[1]) - origin).to_i / 7
      }
      weekly = weekly.find_all {|w, _| w >= 0} # originより古いものは隠す
      result = weekly.map {|_, decks|
        {
          'range' => Range.new(decks[0][1], decks[-1][1]),
          'deck_count' => decks.size,
          'cluster' => Cluster.new(world, decks.map {|x, d| x})
        }
      }
      result.each do |x|
        x['cluster'].join
      end
      result
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