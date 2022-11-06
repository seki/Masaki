class SingleLinkage
  Cell = Struct.new(:x, :y, :value)
  class Cell
    def <=>(other)
      self.to_f <=> other.to_f
    end

    def to_f
      self.value
    end

    def move(x, y)
      self.x = x
      self.y = y
    end
  end

  def initialize(name)
    @name = name
    @size = @name.size
    @cluster_size = [1] * (@name.size * 2 - 1)
    @matrix = []
    @min = []

    (1..(@size-1)).each do |y|
      y.times do |x|
        cell = Cell.new(x, y, yield(@name[x], @name[y]))
        self[x, y] = cell
        # self[y, x] = cell
        @min << cell
      end
    end

    @min.sort!
  end
  attr_reader :matrix

  def min
    while it = @min.shift
      next unless self[it.x, it.y]
      return it
    end
    it
  end

  def [](x, y)
    @matrix.dig(y, x) || @matrix.dig(x, y)
  end

  def []=(x, y, z)
    @matrix[y] ||= []
    @matrix[y][x] = z
  end

  def remove(i)
    @matrix[i] = []
    @matrix.each do |r|
      next unless r
      next if r.empty?
      r[i] = nil
    end
  end

  def main
    (@matrix.size - 1).times do |n|
      it = step
      yield(*it)
    end
  end

  def move(x0, y0, x1, y1)
    it = self[x0, y0]
    self[x0, y0] = nil
    return unless it
    it.move(x1, y1)
    self[x1, y1] = it
  end

  def step
    cell = min
    x, y, v = cell.to_a

    c = @cluster_size[@matrix.size] = @cluster_size[x] + @cluster_size[y]
    self[x, y] = nil

    t = @matrix.size
    t.times do |n|
      m = [self[n, x], self[n, y]].compact.min
      next unless m
      self[n, t] = m
      m.move(n, t)
    end

    remove(x)
    remove(y)

    [x, y, v, c]
  end
end

if __FILE__ == $0
  d = SingleLinkage.new([2, 11, 5, 1, 7]) do |a, b|
    (a - b).abs
  end
  d.main do |*it|
    p it
    # pp d.matrix
  end
end