require_relative '../src/card-detail'
require_relative '../src/masaki'

def last_month(fname='tools/hateda.txt')
  known = {}
  File.open(fname) do |fp|
    while line = fp.gets
      if /\[(.*)\]\((.*)\)/ =~ line
        known[$1] = $2
      end
    end
  end
  known
end

if __FILE__ == $0
  detail = CardDetail.new
  world = MasakiWorld.new
  xy = JSON.parse(File.read('data/uniq_energy_trainer_xy.txt'))
  latest = world.id_latest
  ary = []
  xy.each do |k, v|
    next if Integer === v
    ary << [detail.card_kind(k), v, latest[k]]
  end

  with_url = true
  diff = ARGV.shift == '-d'
  known = diff ? last_month : Hash.new
  head = nil
  ary.sort.each do |group, name, link|
    next if group == "基本エネルギー"
    url = "https://www.pokemon-card.com/card-search/details.php/card/#{link}"
    unless head == group
      puts "* #{group}"
      head = group
    end
    if with_url
      puts "  * [#{name}](#{url})" unless known[name]
    else
      puts "  * #{name}"
    end
  end
end

