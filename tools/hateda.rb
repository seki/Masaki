require_relative '../src/card-detail'

if __FILE__ == $0
  detail = CardDetail.new
  xy = JSON.parse(File.read('../data/uniq_energy_trainer_xy.txt'))
  latest = Hash[JSON.parse(File.read('../data/derived_latest.txt'))]
  ary = []
  xy.each do |k, v|
    next if Integer === v
    ary << [detail.card_kind(k), v, latest[k]]
  end

  with_url = true
  head = nil
  ary.sort.each do |group, name, link|
    next if group == "基本エネルギー"
    url = "https://www.pokemon-card.com/card-search/details.php/card/#{link}"
    unless head == group
      puts "* #{group}"
      head = group
    end
    if with_url
      puts "  * [#{name}](#{url})"
    else
      puts "  * #{name}"
    end
  end
end
