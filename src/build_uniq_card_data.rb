require_relative 'ptclist'
require_relative 'card-detail'
require 'nkf'

def uniq_card_list(kind, regulation, errata={})
  ary = PTCList.new(kind, regulation).map do |hash|
    name = hash['cardNameAltText'].gsub(/\&amp\;/, '&')
    name = errata[name] || name
    [name, hash['cardID'].to_i]
  end

  last = []
  result = ary.sort.map { |name, card_id|
    if last[0] == name
      [card_id, last[1]]
    else
      last = [name, card_id]
      [card_id, name]
    end
  }
end

def build_trainer_and_energy(regulation)
  errata = Hash.new do |h, k|
    case(k)
    when /\Aボスの指令（.*）\Z/
      "ボスの指令"
    when /\Aボスの指令(.*)\Z/
      "ボスの指令"
    when /\A博士の研究（.*）\Z/
      "博士の研究"
    when /\A博士の研究(.*)\Z/
      "博士の研究"
    else
      k
    end
  end
  errata.update(
    {
      '基本【水】エネルギー' => '基本水エネルギー',
      'ワザマシン　TS-1' => 'ワザマシン TS-1',
      'ワザマシン　TS-2' => 'ワザマシン TS-2'
    }
  )

  uniq_card_list("energy", regulation, errata) + uniq_card_list("trainer", regulation, errata)  
end

def build_pokemon_errata_region_form(name)
  if /\A(アローラ|ヒスイ|ガラル|パルデア)(\S.*)/ =~ name
    return [$1, $2].join(' ')
  elsif name == "裂空の訪問者デオキシス　"
    return "裂空の訪問者デオキシス"
  end
  name
end

def errata_ex_text(ary)
  ary.map {|x|
    x.sub('【ex】', 'ex')
  }
end

def errata_bench_text(ary)
  ary.map {|x|
    x.sub('[ベンチは弱点・抵抗力を計算しない。]', 'ベンチは弱点・抵抗力を計算しない。')
  }
end

def build_pokemon(regulation)
  detail = CardDetail.new
  list = PTCList.new('pokemon', regulation).map do |hash|
    name = hash['cardNameAltText'].gsub(/\&amp\;/, '&')
    name = build_pokemon_errata_region_form(name)
    pair =  [name, hash['cardID'].to_i]
    body = detail[pair[1]]
    ary = ParseRawCard.section(body)
    ary = ParseRawCard.drop_head_pokemon(ary)

    # 全角アスキーを半角に
    ary = ary.map {|x| NKF.nkf('-m0Z1 -W -w', x)}

    # errata 「GXワザ」があったりなかったりするので、先に削除して正規化する。
    ary = ary.reject {|x| x == "GXワザ"}
    ary = errata_bench_text(ary)
    ary = errata_ex_text(ary)
    
    # errata ヤミラミV SR
    if pair[1] == 37879 
      ary.insert(9, '10＋')
    end

    if pair[1] == 44460 && ary[13] == "このポケモンは、ベンチにいるかぎり、ワザのダメージを受けない。"
      ary[5,0] = "このポケモンは、ベンチにいるかぎり、ワザのダメージを受けない。"
      ary[14,1] = []
    end


    [pair.first, ary, pair.last]
  end

  File.open("debug_pokemon.dump", "w") {|fp| Marshal.dump(list, fp)} if regulation == "all"

  last = []
  result = list.sort.map { |name, desc, card_id|
    if last[0..1] == [name, desc]
      [card_id, last[2]]
    else
      last = [name, desc, card_id]
      [card_id, name]
    end
  }

  result
end

p :step_1
all_trainer = build_trainer_and_energy("all")
File.open("uniq_energy_trainer_all.txt", "w") {|fp| fp.write(all_trainer.pretty_inspect)}

p :step_2
all_pokemon = build_pokemon("all")
File.open("uniq_pokemon_all.txt", "w") {|fp| fp.write(all_pokemon.pretty_inspect)}

exit unless ARGV.shift

p :step_3
xy_trainer = build_trainer_and_energy("XY")
File.open("uniq_energy_trainer_xy.txt", "w") {|fp| fp.write(xy_trainer.pretty_inspect)}

p :step_4
xy_pokemon = build_pokemon("XY")
File.open("uniq_pokemon_xy.txt", "w") {|fp| fp.write(xy_pokemon.pretty_inspect)}

