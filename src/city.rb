require 'json'
require_relative 'world'
require_relative 'masaki-pg'
require_relative 'single_linkage'
require 'set'

city = JSON.parse(File.read(ARGV.shift))
unless File.exist?('city_frozen.json')
  frozen = MasakiPG::KVS.frozen('deck')
  city_deck = Set.new(city.map(&:first))
  it = frozen.find_all {|k, v| city_deck.include?(k) }
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

module Cluster
  module_function
  def make_tree(world, decks, threshold=nil)
    cluster = decks.map {|x| Leaf.new(x, world.deck[x])}
    dist_matrix = SingleLinkage.new(decks) do |a, b|
      1 - world.cos(a, b).clamp(0,1.0)
    end
    dist_matrix.main do |a, b, dist, size|
      break if threshold && dist > threshold
      left = cluster[a]
      right = cluster[b]
      cluster[a] = nil
      cluster[b] = nil
      cluster << Node.new(left, right, dist, size)
    end
    cluster.compact
  end

  class DeckSum
    def initialize
      @total = Hash.new(0)
    end
    attr_reader :total

    def to_a
      @total.to_a.sort
    end

    def add(deck)
      deck.each do |k, v|
        @total[k] += v.clamp(..4)
      end
    end
  end

  class Node
    def initialize(left, right, dist, size)
      if dist == 0
        @children = left.to_a + right.to_a
      else
        @children = [left, right]
      end
      @dist = dist
      @size = size
    end
    attr_reader :dist

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

    def sum(total=DeckSum.new)
      @children.each do |node|
        node.sum(total)
      end
      total
    end
  end

  class Leaf
    def initialize(name, deck)
      @name = name
      @deck = deck
    end
    attr_reader :name, :deck

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

    def sum(total)
      total.add(@deck)
      total
    end
  end

  def merge(a, b, dist, size)
    @cluster << Node.new(a, b, dist, size)
  end
end

world = MyWorld.new

decks = city.find_all {|k, d| d >= '2022-10-22'}.map {|k, d| k}.to_a
p decks.size

tree = Cluster.make_tree(world, decks, 0.1)

it = tree.max_by(10) {|x| x.size}
it.each do |x|
  sum = x.sum.to_a
  pp [x.size, world.deck_desc_for_cluster(sum, 15)]
end

# File.write('tree3.json', JSON.generate(it, :max_nesting => false))

# File.write('tree2.json', JSON.generate(tree.to_h, :max_nesting => false))