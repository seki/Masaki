require "pg"
require "monitor"
require "pp"
require_relative "masaki-s3"

class MasakiPG
  include MonitorMixin

  class KVS
    def initialize(name)
      @table = name
    end

    def db
      MasakiPG.instance
    end

    def [](key)
      db.kvs_fetch(@table, key)
    end

    def []=(key, value)
      db.kvs_store(@table, key, value)
    end

    def include?(key)
      db.kvs_exists?(@table, key)
    end

    def each(&blk)
      db.kvs_each(@table, &blk)
    end

    def each_by_value(&blk)
      db.kvs_each_by_value(@table, &blk)
    end

    def each_by_int_key(&blk)
      db.kvs_each_by_int_key(@table, &blk)
    end

    def size
      db.kvs_size(@table)
    end

    def keys
      db.kvs_keys(@table)
    end

    def max_key
      db.kvs_max_key(@table)
    end

    def delete(key)
      db.kvs_delete(@table, key)
    end
  end

  class KVS
    def self.frozen(name)
      JSON.parse(MasakiS3::KVS.new[name]) rescue {}
    end
  end

  def self.instance
    @instance = self.new unless @instance
    @instance.synchronize do
      @instance = self.new unless @instance.ping
    end
    return @instance
  rescue
    nil
  end

  def initialize
    super()
    url = ENV['DATABASE_URL'] || 'postgres:///masaki'
    @conn = PG.connect(url)
    @conn.type_map_for_results = PG::BasicTypeMapForResults.new(@conn)
  end
  attr :conn

  def ping
    @conn.exec("select 1")
    true
  rescue
    false
  end

  def kvs_create_table(table)
    sql =<<EOB
create table #{table}(
id varchar(255)
, value text
, primary key(id));
EOB
    @conn.transaction do |c|
      c.exec(sql)
    end
  end

  def kvs_exists?(table, key)
    synchronize do
      sql = "select id from #{table} where id=$1"
      @conn.exec_params(sql, [key]).to_a.size > 0
    end
  end

  def kvs_size(table)
    synchronize do
      sql = "select count(id) from #{table}"
      @conn.exec(sql).to_a.dig(0, 'count').to_i
    end
  end

  def kvs_fetch(table, key)
    synchronize do
      sql = "select value from #{table} where id=$1"
      @conn.exec_params(sql, [key]).to_a.dig(0, 'value')
    end
  end

  def kvs_store(table, key, value)
    sql = <<EOB
insert into #{table} (id, value) values ($1, $2)
ON CONFLICT ON CONSTRAINT #{table}_pkey do update set
  value = $2
EOB
    synchronize do
      @conn.exec_params(sql, [key, value])
    end
  end

  def kvs_each(table, &blk)
    synchronize do
      sql = "select id, value from #{table} order by id"
      @conn.exec(sql)
    end.each {|x| yield(x["id"], x['value'])}
  end

  def kvs_each_by_value(table, &blk)
    synchronize do
      sql = "select id, value from #{table} order by value"
      @conn.exec(sql)
    end.each {|x| yield(x["id"], x['value'])}
  end

  def kvs_each_by_int_key(table, &blk)
    synchronize do
      sql = "select id, value from #{table} order by cast(id as int)"
      @conn.exec(sql)
    end.each {|x| yield(x["id"], x['value'])}   
  end

  def kvs_keys(table)
    synchronize do
      sql = "select id from #{table} order by id"
      @conn.exec(sql)
    end.map{|x| x["id"]}
  end

  def kvs_max_key(table)
    synchronize do
      sql = "select max(id) from #{table}"
      @conn.exec(sql).to_a.dig(0, 'max')
    end
  end

  def kvs_delete(table, key)
    synchronize do
      sql = "delete from #{table} where id=$1"
      @conn.exec_params(sql, [key])
    end
  end

  def kvs_frozen_world(table)
    synchronize do
      @conn.transaction do |conn|
        it = conn.exec_params("select * from #{table}")
        hash = Hash[it.map{|x| [x['id'], x['value']]}]

        world = MasakiS3::KVS.new
        last = JSON.parse(world[table]) rescue {}
        last.update(hash)
        world[table] = last.to_json

        hash.each do |k, v|
          delete_sql = "delete from #{table} where id=$1"
          conn.exec_params(delete_sql, [k])
        end
        last
      end
    end
  end

  def referer_tw_create_table
    sql =<<EOB
    create table referer_tw (
    deck varchar(32)
    , id_str varchar(32)
    , visited timestamp
    , created timestamp
    , tweet jsonb
    , primary key(id_str, deck));
EOB
  end

  def referer_tw_store(tweet, deck)
    sql =<<EOB
    insert into referer_tw (deck, id_str, visited, created, tweet) values ($1, $2, $3, $4, $5)
    on conflict do nothing
EOB
    synchronize do
      @conn.exec_params(sql, [deck, tweet[:id_str], Time.now, DateTime.parse(tweet[:created_at]), tweet.to_json])
    end  
  end

  def referer_tw_link(deck)
    sql =<<EOB
select id_str, tweet->'user'->'screen_name' as screen_name from referer_tw where deck=$1 order by created limit 1;
EOB
    synchronize do
      it = @conn.exec_params(sql, [deck]).to_a.first
      if it
        "https://twitter.com/#{it['screen_name']}/status/#{it['id_str']}"
      else
        "https://twitter.com/search?q=#{deck}"
      end
    end  
  end

  def referer_tw_detail(deck)
    sql =<<EOB
select id_str, created, tweet->'user'->'screen_name' as screen_name from referer_tw where deck=$1 order by created limit 1;
EOB
    synchronize do
      @conn.exec_params(sql, [deck]).to_a.dig(0)
    end  
  end

  def referer_tw_screen_name(screen_name, n=20)
    sql =<<EOB
select deck, id_str, created, tweet->'user'->'screen_name' as screen_name from referer_tw as r1
where
  tweet #>> '{user,screen_name}' = $1
and not exists (
  select 1 from referer_tw as r2 where r1.deck = r2.deck and r1.created > r2.created
)
order by created desc limit $2;
EOB
    synchronize do
      @conn.exec_params(sql, [screen_name, n]).to_a
    end  
  end

  def referer_tw_recent(n=10)
    sql =<<EOB
    select deck from referer_tw group by deck order by min(created) desc limit $1;
EOB
    synchronize do
      @conn.exec_params(sql, [n]).to_a.map {|x| x['deck']}
    end
  end
end

if __FILE__ == $0
  # MasakiPG::instance.kvs_create_table("world")
  # MasakiPG::instance.kvs_create_table("deck")
  # MasakiPG::instance.kvs_create_table("cache")
  pp MasakiPG::instance.kvs_frozen_world("deck")
  deck = MasakiPG::KVS.frozen('deck')
  pp deck.keys
end

