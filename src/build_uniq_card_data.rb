require_relative 'ptclist'
require_relative 'card-detail'

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
  errata = {
    '基本【水】エネルギー' => '基本水エネルギー',
    'ボスの指令（サカキ）' => 'ボスの指令',
    '博士の研究（マグノリア博士）' => '博士の研究'
  }
  uniq_card_list("energy", regulation, errata) + uniq_card_list("trainer", regulation, errata)  
end

def build_pokemon(regulation)
  detail = CardDetail.new
  list = PTCList.new('pokemon', regulation).map do |hash|
    name = hash['cardNameAltText'].gsub(/\&amp\;/, '&')
    pair =  [name, hash['cardID'].to_i]
    body = detail[pair[1]]
    ary = ParseRawCard.section(body)
    ary = ParseRawCard.drop_head_pokemon(ary)
    # errata 「GXワザ」があったりなかったりするので、先に削除して正規化する。
    ary = ary.reject {|x| x == "GXワザ"}

    [pair.first, ary, pair.last]
  end

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
xy_trainer = build_trainer_and_energy("XY")
File.open("uniq_energy_trainer_xy.txt", "w") {|fp| fp.write(xy_trainer.pretty_inspect)}

p :step_3
all_pokemon = build_pokemon("all")
File.open("uniq_pokemon_all.txt", "w") {|fp| fp.write(all_pokemon.pretty_inspect)}

p :step_4
xy_pokemon = build_pokemon("XY")
File.open("uniq_pokemon_xy.txt", "w") {|fp| fp.write(xy_pokemon.pretty_inspect)}

