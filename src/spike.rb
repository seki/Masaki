require 'matrix'
require 'set'

class World
  def initialize(fname=nil)
    @cos = File.open(fname) {|fp| Marshal.load(fp)}
    keys = Set.new
    @cos.keys.each {|ab| keys << ab[0]; keys << ab[1]}
    @keys = keys.to_a 
  end
  attr_reader :cos, :pos

  def make_pos
    @zero = Vector[0, 0, 0]
    @pos = {}
    @keys.each do |k, v|
      # @pos[k] = rand + rand * 1i
      @pos[k] = Vector[rand, rand, rand]
      #@pos[k] = rand * 2 - 1
    end
  end

  def iterate
    old_pos = @pos.dup
    @cos.each do |ab, cos|
      pivot, other = ab
      diff = old_pos[other] - old_pos[pivot]

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

end

w = World.new('cos.dump')
w.make_pos

require 'gnuplot'
Gnuplot.open do |gp|
  Gnuplot::SPlot.new(gp) do |plot|
    w.normalize_pos
    plot.data << Gnuplot::DataSet.new(w.pos.map {|k, v| v.to_a}.transpose)
    1000.times do |n|
      if (n + 1) % 100 == 0
        p n
        w.normalize_pos
        plot.data << Gnuplot::DataSet.new(w.pos.map {|k, v| v.to_a}.transpose)
      end
      w.iterate
    end
  end
  gp.puts; gets
end

w.normalize_pos
# pp w.pos

