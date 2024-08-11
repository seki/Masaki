require_relative 'src/world'

$world = MasakiWorld.new

ary = Masaki::Meta.db { |d|
  d.execute("select deck from referer_all;").map {|x| x['deck']}
}

ary.each do |name|
  unless $world.deck[name]
    $world.add(name, true)
    p name
    sleep(rand * 0.5)
  end
end