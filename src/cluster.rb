require 'json'
require 'set'
require_relative 'world'
require_relative 'single_linkage'

class Cluster
  def initialize(world, decks)
    @decks = decks
    @cluster = make_tree(world, decks)
  end

  def [](index)
    @cluster[index]
  end

  def threshold(diff, clip=nil)
    @cluster.find_all {|x|
      x.dist < diff &&
      x.parent && x.parent.dist > diff &&
      (clip ? x.ancestor?(clip) : true)
    }
  end

  def make_tree(world, decks)
    index = -1
    cluster = decks.map {|x| index += 1; Leaf.new(x, world.deck[x], index)}
    dist_matrix = SingleLinkage.new(decks) do |a, b|
      1 - world.cos(a, b).clamp(0,1.0)
    end
    dist_matrix.main do |a, b, dist, size|
      left = cluster[a]
      right = cluster[b]
      index += 1
      cluster << Node.new(left, right, dist, size, index)
    end
    cluster
  end

  def self.make_tree(world, decks, diff)
    c = self.new(world, decks)
    c.threshold(diff).map {|x, i| x}
  end

  class Node
    def initialize(left, right, dist, size, index)
      if dist == 0
        @children = left.to_a + right.to_a
      else
        @children = [left, right]
      end
      @dist = dist
      @size = size
      @index = index
      @parent = nil
      left.parent = self
      right.parent = self
    end
    attr_reader :dist, :index
    attr_accessor :parent

    def to_h
      {
        'children' => @children.map {|x| x.to_h},
        'height' => @dist,
        'size' => @size,
        'index' => -1,
        'isLeaf' => false
      }
    end

    def size
      @size
    end

    def [](i)
      @children[i]
    end

    def leaf?
      false
    end

    def to_a
      @children
    end

    def sample
      @children.max_by {|x| x.size}.sample
    end

    def ancestor?(index)
      return true if @index == index
      return false unless @parent
      @parent.ancestor?(index)
    end
  end

  class Leaf
    def initialize(name, deck, index)
      @name = name
      @deck = deck
      @parent = nil
      @index = index
    end
    attr_reader :name, :deck, :index
    attr_accessor :parent

    def to_h
      {
        'children' => [],
        'height' => 0,
        'size' => 1,
        'name' => @name,
        'isLeaf' => true
      }
    end

    def dist
      0
    end

    def leaf?
      true
    end

    def to_a
      [self]
    end

    def size
      1
    end

    def sample
      @name
    end

    def ancestor?(index)
      return true if @index == index
      return false unless @parent
      @parent.ancestor?(index)
    end
  end
end

if __FILE__ == $0
  require_relative 'world'

  world = MasakiWorld.new
  city = JSON.parse(File.read('city-deck-date.json'))
  decks = city.find_all {|k, d| d >= '2022-11-18'}.map {|k, d| k}.to_a
  p decks.size

  cluster = Cluster.new(world, decks)
  File.write("cluster.dump", Marshal.dump(cluster))
  th = 0.5

  ary = cluster.threshold(th ** 2).max_by(10) {|x| x.size}
  pp ary.map {|x| [x.index, x.size]}

  (3..6).each do |n|
    ary = cluster.threshold(th ** n, ary[0].index).max_by(10) {|x| x.size}
    pp world.diff(
      cluster[ary[0].index].sample, 
      cluster[ary[1].index].sample
    ).find_all {|x| x[2][0] != x[2][1]}
  end

end