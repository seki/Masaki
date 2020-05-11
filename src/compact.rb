require 'pp'

p :phase_2
trainer = eval(File.read("uniq_energy_trainer_all.txt"))
pokemon = eval(File.read("uniq_pokemon_all.txt"))

ary = (trainer + pokemon).map do |k, v|
  v = k if String === v
  [k, v]
end

compaction = ary.inject([]) do |a, b|
  a[b[0]] = b[1]
  a
end

File.open("compact.dump", "w") {|fp| Marshal.dump(compaction, fp)}

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

File.open("latest.txt", "w") {|fp| fp.write(latest.pretty_inspect)}