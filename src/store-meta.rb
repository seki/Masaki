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

    def close
      @db.close if @db
    ensure
      @db = nil
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
select deck from referer_tw order by created_at desc limit ?;
EOB
      synchronize do
        @db.execute(sql, [n]).to_a.map {|x| x['deck']}
      end
    end
  end

  Meta = MetaStore.new(__dir__ + '/../data/meta.db')
end

if __FILE__ == $0
  Masaki::Meta.referer_tw_create_table rescue nil

  require_relative 'masaki-pg'
  pg = MasakiPG::instance
  list = pg.conn.exec("select deck, tweet from referer_tw;")
  list.each do |row|
    pp row['tweet']['created_at']
    Masaki::Meta.referer_tw_store(row['tweet'], row['deck'])
  end
end

