require 'matrix'

class World
  def initialize
    make_sample
    make_cos
  end
  attr_reader :sample, :cos, :pos

  def make_pos
    @zero = Vector[0, 0, 0]
    @pos = {}
    @sample.each do |k, v|
      # @pos[k] = rand + rand * 1i
      @pos[k] = Vector[rand, rand, rand]
      #@pos[k] = rand * 2 - 1
    end
  end

  def iterate
    old_pos = @pos.dup
    @sample.keys.combination(2) do |pivot, other|
      diff = old_pos[other] - old_pos[pivot]
      cos = (@cos[[pivot, other]] || @cos[[other, pivot]])

      r = diff.magnitude
      if r > 0.0
        r = [1, 1 / r ** 2].min
        d = cos * 0.0001 * r
        v = diff.normalize

        @pos[other] = @pos[other] - v * d
        @pos[pivot] = @pos[pivot] + v * d
      end
    end

  end

  def normalize_pos
    mean = @pos.values.inject(@zero, &:+) / @pos.size
    dev = @pos.values.inject(0) { |a, b|
      a + (b - mean).magnitude ** 2
    } / @pos.size
    s = Math.sqrt(dev)

    @pos.to_a.each do |k, v|
      @pos[k] = (v - mean) / s
    end
  end

  N = 20
  def make_sample
    @sample = Hash.new
    name = "001"
    N.times do
      [0,1,2,3].combination(2).each do |on1, on2|
        abcd = [1, 1, 1, 1] 
        abcd[on1] = 8
        abcd[on2] = 8
        a, b, c, d = abcd
        @sample[name] = Vector[a + a * rand, b + b * rand, c + c * rand, d + d * rand, rand, rand, rand, rand ].normalize
        name = name.succ
      end
    end
  end

  def make_cos
    @cos = @sample.keys.combination(2).inject({}) do |h, key|
      h[key] = @sample[key[0]].dot(@sample[key[1]])
      h
    end

    mean = @cos.values.sum / @cos.size
    dev = @cos.values.inject(0) { |a, b|
      a + (b - mean).magnitude ** 2
    } / @cos.size
    s = Math.sqrt(dev)

    pp [@cos.size, mean, dev]

    @cos.to_a.each do |k, v|
      @cos[k] = (v - mean) / s
    end
  end
end

w = World.new
w.make_pos

require 'gnuplot'
Gnuplot.open do |gp|
  Gnuplot::SPlot.new(gp) do |plot|
    x = w.pos.map {|k,v| v[0]}
    y = w.pos.map {|k,v| v[1]}
    z = w.pos.map {|k,v| v[2]}
    plot.data << Gnuplot::DataSet.new([x, y, z])
    w.normalize_pos
    x = w.pos.map {|k,v| v[0]}
    y = w.pos.map {|k,v| v[1]}
    z = w.pos.map {|k,v| v[2]}
    plot.data << Gnuplot::DataSet.new([x, y, z])
  end
  gp.puts; gets
end






1000.times do |n|
  w.iterate
end
# pp w.pos
w.normalize_pos
# pp w.pos

File.open("3d.dat", "w") do |fp|
  w.pos.each do |k,v|
    fp.puts v.to_a.join("\t")
  end
end
