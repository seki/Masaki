require 'pp'

trainer = eval(File.read("../data/uniq_energy_trainer_all.txt"))
pokemon = eval(File.read("../data/uniq_pokemon_all.txt"))

ary = (trainer + pokemon).map do |k, v|
  v = k if String === v
  [k, v]
end

norm = ary.inject({}) do |a, b|
  if b[0] != b[1]
    a[b[0]] = b[1]
  end
  a
end

# カードを正規化するためのLUT。同じテキストの最小値を求める
# norm[key] || key
# File.open("../data/derived_norm.dump", "w") {|fp| Marshal.dump(norm, fp)}
File.open("../data/derived_norm.txt", "w") {|fp| fp.write(norm.pretty_inspect)}

latest = ary.sort_by {|k, v| [v, -k]}
last = []
latest = latest.map do |k, v|
  if last[1] != v
    last = [k, v]
    [k, k]
  else
    [k, last[0]]
  end
end

# 同じテキストカードの最大値（≒最新のカード）を返すLUT
# latest[key]
File.open("../data/derived_latest.txt", "w") {|fp| fp.write(latest.pretty_inspect)}

