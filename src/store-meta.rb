require "sqlite3"
require 'time'
require "monitor"
require "pp"

class Masaki
  class MetaStore
    include MonitorMixin

    def as_time(time)
      time.utc.strftime("%Y-%m-%d %H:%M:%S")
    end

    def to_time(str)
      Time.parse(str + " UTC")
    end

    def initialize(fname)
      super()
      @db = SQLite3::Database.new(fname)
      @db.results_as_hash = true
    end

    def db
      synchronize do
        yield(@db)
      end
    end

    def close
      @db.close if @db
    ensure
      @db = nil
    end

    def referer_all_create_view
      sql =<<EOQ
    create view referer_all as 
      select coalesce(referer_google.deck, referer_city.deck, referer_tw.deck) as deck, *, coalesce(created_at, event_date, search_date) as date 
      from referer_tw 
        full outer join referer_google on referer_tw.deck = referer_google.deck
          full outer join referer_city on referer_google.deck = referer_city.deck;
EOQ
      synchronize do
        @db.execute(sql)
      end
    end

    def referer_all_create_table
      sql =<<EOQ
    create table referer_all (
    deck text
    , date text
    , primary key(deck));
EOQ
      synchronize do
        @db.execute(sql)
      end
    end

    def referer_all_store(deck, date)
      sql =<<EOQ
insert into referer_all (deck, date)
  values (:deck, :date)
  on conflict(deck) do update set
    date = case when date > :date then :date else date end;
EOQ
      synchronize do
        @db.execute(sql,
          :deck => deck, :date => date
        )
      end
    end

    def referer_google_create_table
      sql =<<EOQ
    create table referer_google (
    deck text
    , search_date text
    , primary key(deck));
EOQ
      synchronize do
        @db.execute(sql)
      end
    end

    def referer_google_store(deck, search_date)
      sql =<<EOQ
insert into referer_google (deck, search_date)
  values (:deck, :search_date)
  on conflict do update set
    search_date = case when search_date > :search_date then :search_date else search_date end;
EOQ
      synchronize do
        @db.execute(sql,
          :deck => deck, :search_date => search_date
        )
      end
    end

    def referer_google_detail(deck)
      sql =<<EOB
select search_date from referer_google where deck=:deck;
EOB
      synchronize do
        @db.execute(sql, :deck => deck).to_a.dig(0)
      end
    end

    def referer_google_recent(n=10)
      sql =<<EOB
select deck, date from referer_all order by date desc, deck limit ?;
EOB
      synchronize do
        @db.execute(sql, [n]).to_a.map {|x|
          [x['deck'], to_time(x['date'])]
        }
      end
    end
      
    def referer_city_create_table
      sql =<<EOQ
    create table referer_city (
    deck text
    , event_date text
    , primary key(deck));
EOQ
      synchronize do
        @db.execute(sql)
      end
    end

    def referer_city_store(deck, event_date)
      sql =<<EOQ
insert into referer_city (deck, event_date)
  values (:deck, :event_date)
  on conflict do update set
    event_date = case when event_date > :event_date then :event_date else event_date end;
EOQ
      synchronize do
        @db.execute(sql,
          :deck => deck, :event_date => event_date
        )
      end
    end

    def referer_city_detail(deck)
      sql =<<EOB
select event_date from referer_city where deck=:deck;
EOB
      synchronize do
        @db.execute(sql, :deck => deck).to_a.dig(0)
      end
    end

    def referer_tw_create_table
      sql =<<EOQ
    create table referer_tw (
    deck text
    , id_str text
    , created_at text
    , screen_name text
    , primary key(deck));
EOQ
      synchronize do
        @db.execute(sql)
      end
    end

    def do_referer_tw_store(deck, id_str, created_at, screen_name)
      sql =<<EOQ
insert into referer_tw (deck, id_str, created_at, screen_name)
  values (:deck, :id_str, :created_at, :screen_name)
  on conflict do update set
    id_str = case when created_at > :created_at then :id_str else id_str end,
    created_at = case when created_at > :created_at then :created_at else created_at end,
    screen_name = case when created_at > :created_at then :screen_name else screen_name end;
EOQ
      synchronize do
        @db.execute(sql,
          :deck => deck, :id_str => id_str,
          :created_at => created_at, :screen_name => screen_name
        )
      end
    end

    def referer_tw_store(tweet, deck)
      screen_name = tweet.dig(:user, :screen_name) || tweet.dig('user', 'screen_name')
      id_str = tweet[:id_str] || tweet['id_str']
      created_at = Time.parse(tweet[:created_at] || tweet["created_at"])
      do_referer_tw_store(deck, id_str, as_time(created_at), screen_name)
    end

    def referer_tw_link(deck)
      sql =<<EOB
select id_str, screen_name from referer_tw where deck=:deck;
EOB
      synchronize do
        it = @db.execute(sql, :deck => deck).to_a.first
        if it
          "https://twitter.com/#{it['screen_name']}/status/#{it['id_str']}"
        else
          "https://twitter.com/search?q=#{deck}"
        end
      end
    end

    def referer_tw_detail(deck)
      sql =<<EOB
select id_str, created_at, screen_name from referer_tw where deck=:deck;
EOB
      synchronize do
        it = @db.execute(sql, :deck => deck).to_a.dig(0)
        return nil unless it
        it['created'] = to_time(it['created_at'])
        it
      end
    end

    def referer_tw_screen_name(screen_name, n=20)
      sql =<<EOB
select deck, id_str, created_at, screen_name from referer_tw
where screen_name= ?
order by created_at desc limit ?;
EOB
      synchronize do
        @db.execute(sql, [screen_name, n]).map {|it|
          it['created'] = to_time(it['created_at'])
          it
        }
      end  
    end

    def referer_tw_recent(n=10)
    sql =<<EOB
select deck, created_at from referer_tw order by created_at desc limit ?;
EOB
      synchronize do
        @db.execute(sql, [n]).to_a.map {|x|
          [x['deck'], to_time(x['created_at'])]
        }
      end
    end
  end

  Meta = MetaStore.new(__dir__ + '/../data/meta.db')
  Meta.referer_tw_create_table rescue nil
  Meta.referer_city_create_table rescue nil
  Meta.referer_google_create_table rescue nil
  Meta.referer_all_create_table rescue nil
end

if __FILE__ == $0
  require_relative 'world'
  require_relative 'deck-detail'
  require_relative 'store-deck'
  require 'date'

  Masaki::Deck.each_new_arrive do |name, deck|
    num = deck.inject(0) {|s, x| s + x[1]} || 0
    if num == 60 || num == 40 || num == 30
      pp [num, :skip, name]
      next
    end
    sleep 0.3 + rand
    pp [num, name]
    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    Masaki::Deck[name] = v
  end
end

