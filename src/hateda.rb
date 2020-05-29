require_relative 'card-detail'

class Hateda
  def initialize
    @detail = CardDetail.new
    @errata = {
      38237 => "特殊エネルギー",
      38238 => "特殊エネルギー",
      38229 => "グッズ",
      37998 => "ポケモンのどうぐ"
    }
  end

  def kind(key)
    body = @detail[key]
    ary = ParseRawCard.section(body)
    if @errata[key]
      return @errata[key]
    else
      return ParseRawCard.kind_trainer_energy(ary)
    end
    raise 'invalid'
  end
end

if __FILE__ == $0
  hateda = Hateda.new
  it = eval(File.read('../data/uniq_energy_trainer_xy.txt'))
  latest = Hash[eval(File.read('../data/derived_latest.txt'))]
  ary = []
  it.each do |k, v|
    next if Integer === v
    ary << [hateda.kind(k), v, latest[k]]
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

