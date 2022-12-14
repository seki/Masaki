require 'json'
require 'set'
require_relative 'world'
require_relative 'single_linkage'

class Cluster
  def initialize(world, decks)
    @cluster = self.class.make_tree_r(world, decks)
  end

  def join
    @cluster = @cluster.take
  rescue
  end
  
  def to_a
    @cluster
  end

  def inspect
    "<Cluster>"
  end

  def pretty_inspect
    "<Cluster>"
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

  def do_division(ary, n)
    return ary if ary.size >= n
    top = ary.pop
    return ary if top.to_a.size <= 1
    ary += top.to_a
    do_division(ary.sort_by {|x| x.index}, n)
  end

  def division(index, n)
    do_division([@cluster[index]], n)
  end

  def self._make_tree(r, all_deck, deck_name)
    index = -1
    cluster = deck_name.map {|x| index += 1; Leaf.new(x, index)}
    dist_matrix = SingleLinkage.new(deck_name) do |ia, ib|
      1 - r._cos(all_deck[ia], all_deck[ib]).clamp(0,1.0)
    end
    dist_matrix.main do |a, b, dist, size|
      left = cluster[a]
      right = cluster[b]
      index += 1
      cluster << Node.new(left, right, dist, size, index)
    end
    cluster
  end

  def self.make_tree_r(world, decks)
    all_deck = decks.map {|x| world.deck[x]}
    Ractor.new(world.ractor, all_deck, decks) {|world, all_deck, decks|
      Cluster._make_tree(world, all_deck, decks)
    }
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
    def initialize(name, index)
      @name = name
      @parent = nil
      @index = index
    end
    attr_reader :name, :index
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
  decks = city.find_all {|k, d| d >= '2022-11-10'}.map {|k, d| k}.to_a
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

  pp cluster.division(2855, 10).map {|x| [x.index, x.size, x.dist]}.reverse
  pp cluster.threshold(cluster[2855].dist * 0.5, 2855).max_by(10) {|x| x.size}.map {|x| [x.index, x.size]}
end