require 'json'

class PTCList
  KIND = %w(pokemon trainer energy)
  REGULATION = %w(all bw xy)

  def self.enum(kind, regulation)
    self.new(kind, regulation).chain(self.new(kind, regulation, true))
  end

=begin
{"cardID"=>"36256",
 "cardThumbFile"=>
  "/assets/images/card_images/large/ENE/036256_E_KIHONTOUENERUGI.jpg",
 "cardNameAltText"=>"基本闘エネルギー",
 "cardNameViewText"=>"基本闘エネルギー"}
=end

  include Enumerable

  def initialize(kind="", regulation="all", mirror=false)
    @queue = SizedQueue.new(1)
    @regulation = regulation
    @kind = kind
    @mirror = mirror
    Thread.new { run }
  end
  attr_reader :size

  def make_curl(page)
    if @mirror
      <<EOS
curl -s -o - 'https://www.pokemon-card.com/card-search/resultAPI.php?keyword=&se_ta=#{@kind}&regulation_sidebar_form=#{@regulation}&pg=&sc_rare_mirror=1&illust=&sm_and_keyword=true&page=#{page}'
EOS
    else
    <<EOS
curl -s -o - 'https://www.pokemon-card.com/card-search/resultAPI.php?keyword=&se_ta=#{@kind}&regulation_sidebar_form=#{@regulation}&pg=&illust=&sm_and_keyword=true&page=#{page}'
EOS
    end
  end

  def get_page(pg)
    begin
      str = IO.popen(make_curl(pg), "r") {|io| io.read}
    rescue => e
      pp [:retry, @kind, pg, e]
      sleep 5
      retry
    end
    begin
      return JSON.parse(str)
    rescue => e
      pp [:invalid_json, str, e]
      sleep 5
      retry
      # return nil
    end
  end

  def run
    pg = 1
    while true
      page = get_page(pg)
      break unless page
      @size = page["hitCnt"]
      @queue.push(page["cardList"])
      break if page["thisPage"] == page["maxPage"]
      pg += 1
    end
    @queue.close
  end

  def each(&blk)
    while list = @queue.pop
      list.each(&blk)
    end
  end
end

