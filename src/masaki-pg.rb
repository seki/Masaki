require "pg"
require "monitor"
require "pp"

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
      JSON.parse(MasakiPG::KVS.new('world')[name]) rescue {}
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
        world = conn.exec_params("select * from world where id=$1", [table])
        last = JSON.parse(world.to_a.dig(0, 'value')) rescue {}
        last.update(hash)
        store_sql = <<EOB
insert into world (id, value) values ($1, $2)
ON CONFLICT ON CONSTRAINT world_pkey do update set
  value = $2
EOB
        conn.exec_params(store_sql, [table, last.to_json])
        hash.each do |k, v|
          delete_sql = "delete from #{table} where id=$1"
          conn.exec_params(delete_sql, [k])
        end
      end
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

