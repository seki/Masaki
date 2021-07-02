require 'json'

class PTCList
  KIND = %w(pokemon trainer energy)
  REGULATION = %w(all bw xy)

=begin
{"cardID"=>"36256",
 "cardThumbFile"=>
  "/assets/images/card_images/large/ENE/036256_E_KIHONTOUENERUGI.jpg",
 "cardNameAltText"=>"基本闘エネルギー",
 "cardNameViewText"=>"基本闘エネルギー"}
=end

  include Enumerable

  def initialize(kind="", regulation="all")
    @queue = SizedQueue.new(1)
    @regulation = regulation
    @kind = kind
    Thread.new { run }
  end
  attr_reader :size

  def make_curl(page)
    <<EOS
curl 'https://www.pokemon-card.com/card-search/resultAPI.php' -s -o - \
-XPOST \
-H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
-H 'Accept: application/json, text/javascript, */*; q=0.01' \
-H 'Host: www.pokemon-card.com' \
-H 'Accept-Language: ja-jp' \
-H 'Accept-Encoding: br, gzip, deflate' \
-H 'Origin: https://www.pokemon-card.com' \
-H 'Referer: https://www.pokemon-card.com/card-search/index.php?mode=statuslist&pg=2' \
-H 'Connection: keep-alive' \
-H 'X-Requested-With: XMLHttpRequest' \
--data 'keyword=&se_ta=#{@kind}&regulation_sidebar_form=#{@regulation}&pg=&illust=&sm_and_keyword=true&ses=1&page=#{page}'
EOS
  end

  def get_page(pg)
    IO.popen(make_curl(pg), "r") {|io|
      str = io.read
      return JSON.parse(str)
    }
  rescue
    pp [:retry, pg]
    sleep 5
    retry
  end

  def run
    pg = 1
    while true
      page = get_page(pg)
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

