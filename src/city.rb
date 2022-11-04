require 'json'
require_relative 'world'
require_relative 'masaki-pg'
require 'set'

city = JSON.parse(File.read(ARGV.shift))
unless File.exist?('city_frozen.json')
  frozen = MasakiPG::KVS.frozen('deck')
  city_deck = Set.new(city.map(&:first))
  it = frozen.find_all {|k, v| city_deck.include?(k)}
  pp it.size
  File.write('city_frozen.json', it.to_json)
  exit
end

class MyWorld < MasakiWorld
  def import_known_deck
    frozen = JSON.parse(File.read('city_frozen.json'))
    import_deck(frozen)
  end
end

class Cluster
  def initialize(decks, dist)
    @decks = decks
    @distance = {}
    dist.each do |ab, cos|
      @distance[ab] = (1 - cos)
    end
    @cluster = @decks.map {|x| Leaf.new(x)}
    @memo = {}
    step_zero
  end
  attr_reader :distance
  attr_reader :cluster

  class Node
    def initialize(left, right, dist)
      if dist == 0
        @children = left.to_a + right.to_a
      else
        @children = [left, right]
      end
      @dist = dist
    end
    attr_reader :dist

    def to_h
      {
        'children' => @children.map {|x| x.to_h},
        'height' => @dist,
        'size' => size,
        'index' => -1,
        'isLeaf' => false
      }
    end

    def size
      @children.sum {|x| x.size}
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

    def flatten
      @flatten ||= @children.inject([]) {|s, x| s + x.flatten}
    end
  end

  class Leaf
    def initialize(name)
      @deck = name
    end
    attr_reader :deck

    def to_h
      {
        'children' => [],
        'height' => 0,
        'size' => 1,
        'name' => @deck,
        'isLeaf' => true
      }
    end

    def dist
      0
    end

    def leaf?
      true
    end

    def flatten
      [self]
    end

    def to_a
      [self]
    end

    def size
      1
    end
  end

  def dist(x, y)
    x = x.flatten
    y = y.flatten
    x.to_a.product(y.to_a).map do |a, b|
      ab = [a.deck, b.deck].sort
      @distance[ab]
    end
  end

  def find_pair
    @cluster.combination(2).map do |ab|
      [ab, @memo[ab] ||= dist(*ab).min]
    end.min_by {|x| x[1]}
  end

  def merge(dist, a, b)
    @cluster.delete(a)
    @cluster.delete(b)
    @cluster << Node.new(a, b, dist)
  end

  def step_zero
    ab, dist = find_pair
    while dist == 0
      merge(dist, *ab)
      ab, dist = find_pair
    end
  end

  def step
    ab, dist = find_pair
    merge(dist, *ab)
    @cluster.size > 1
  end
end

world = MyWorld.new

decks = city.find_all {|k, d| d >= '2022-05-22'}.map {|k, d| k}.to_a
p decks.size

require 'benchmark'

Benchmark.bm do |x|
  a = decks.first
  x.report {
    cos = decks.combination(2).map do |ab|
      [ab.sort, world.cos(*ab).clamp(0,1.0)]
    end
  }
end
cos = decks.combination(2).map do |ab|
  [ab.sort, world.cos(*ab).clamp(0,1.0)]
end

c = Cluster.new(decks, cos)
n = 0
while c.step
  p n
  n += 1
end

def walk(node, level)
  if node.leaf?
    puts node.deck
    return
  end
  p [level, node.dist, node.to_a.size]

  node.to_a.each do |x|
    walk(x, level+1)
  end
end

pp c.cluster[0].class
walk(c.cluster[0], 1)

File.write('tree.json', JSON.generate(c.cluster[0].to_h, :max_nesting => false))