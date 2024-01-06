require_relative 'store-meta'
require_relative 'deck-detail'
require_relative 'erbm'
require_relative 'world'
require_relative 'deck-from-google'
require_relative 'cluster'
require_relative '../city/deck_name'
require 'json'

class Masaki
  include ERB::Util
  View = ERBMethod.new(self, "to_html(req, res)", 'index.html')
  CityView = ERBMethod.new(self, "to_city(req, res)", 'city.html')
  EmbedView = ERBMethod.new(self, "to_embed(req, res, left, right, diff)", 'embed.html')
  def initialize
    @world = MasakiWorld.new
    @datalist = @world.instance_variable_get(:@name_i).map(&:first).uniq
    do_reload_recent
    @recent_updated_at = Time.now
    setup_city
    deck_from_google_thread
  end
  attr_reader :world, :datalist

  CITY_THRESHOLD = 0.25
  def setup_city
    @cluster = File.open('city/weekly.dump') {|fp| Marshal.load(fp)}
    @cluster = @cluster.find_all {|c| c['range'].begin >= "2023-02-03"}
    @cluster_sign = File.mtime('city/weekly.dump').to_i.to_s(36)
    report_for_bar = @cluster.map do |c|
      p c['range']
      ary = c['cluster'].threshold(CITY_THRESHOLD).max_by(8) {|x| x.size}.map do |x|
        [x.size, x.sample, DeckName.guess(@world, x.sample), x.index]
      end
      {
        'range' => c['range'],
        'deck_count' => c['deck_count'],
        'cluster' => ary
      }
    end
    @for_bar = ForBar.new(report_for_bar)
  end

  def do_embed(req, res)
    if /\/(\w{6}\-\w{6}\-\w{6})\.(js|html)\Z/ =~ req.path_info
      left = right = $1
      ext = $2
    elsif /\/(\w{6}\-\w{6}\-\w{6})_(\w{6}\-\w{6}\-\w{6})\.(js|html)\Z/ =~ req.path_info
      left = $1
      right = $2
      ext = $3
    else
      raise 'c' 
    end
    diff = @world.diff(left, right).map {|name, card_no, left_right| [name, card_url(card_no)] + left_right}
    it = to_embed(req, res, left, right, diff)
    if ext == "html"
      %Q(<!DOCTYPE html>
      <html lang="ja">
        <head>
          <meta charset="utf-8">
        </head>
        <body>
          #{it}
        </body>
      </html>)
    else
      return "document.write(#{it.to_json});", "application/javascript; charset=UTF-8"
    end
  rescue
    "/* error */"
  end

  def do_get(req, res)
    View.reload
    to_html(req, res)
  end

  def do_city(req, res)
    p :do_city
    CityView.reload
    p :to_city
    to_city(req, res)
  end

  def do_api(req, res, post)
    case post['method']
    when "search"
      do_search_api(req, res, post)
    when "recent"
      do_recent_api(req, res, post)
    end
  end

  def do_recent_api(req, res, post)
    {
      'recent' => @recent,
      'updated_at' => @recent_updated_at.strftime("%Y-%m-%d %H:%M")
    }
  end

  def do_reload_recent
    @world.reload_recent(15)
    @recent = @world.recent.map {|k, t| [k, deck_desc(k), t.getlocal.strftime("%Y-%m-%d %H:%M")]}
  end

  def do_search_api(req, res, post)
    str = post["search"].encode('utf-8') rescue nil
    add_deck = post["add"] ? true : false
    sign = post["sign"].encode('utf-8') rescue nil
    city_index = guess_city(str)
    return search_city_cluster(city_index, sign) if city_index
    name = DeckDetail::guess_deck_name(str)
    return search(name, 5, add_deck) if name
    screen_name = guess_screen_name(str)
    return search_by_screen_name(screen_name) if screen_name
    card_id = guess_card_id(str)
    return search_by_card(card_id) if card_id
    search_by_name(str)
  end

  def prepare_tw(tw)
    tw['url'] = "https://twitter.com/#{tw['screen_name']}/status/#{tw['id_str']}"
    tw['date'] = tw['created'].strftime("%Y年%m月%d日")
    tw['date2'] = tw['created'].strftime("%Y-%m-%d")
    tw
  end

  def refer_tw(key)
    tw = Masaki::Meta.referer_tw_detail(key)
    return nil unless tw
    prepare_tw(tw)
  end

  def prepare_city(city)
    date = Time.parse(city['event_date']) rescue nil
    return nil unless date
    {
      'date' => date.strftime("%m月%d日") + "の大会で　活躍した。"
    }
  end

  def refer_city(key)
    city = Masaki::Meta.referer_city_detail(key)
    return nil unless city
    prepare_city(city)
  end

  def prepare_google(g)
    date = Time.parse(g['search_date']) rescue nil
    return nil unless date
    {
      'date' => date.strftime("%Y年%m月%d日") + "に　Googleで　出会った。"
    }
  end

  def refer_google(key)
    it = Masaki::Meta.referer_google_detail(key)
    return nil unless it
    prepare_google(it)
  end

  def refer_gen(key)
    refer_city(key) || refer_google(key)
  end

  def search(deck, n, add_deck)
    ary = @world.search_by_deck(deck, n, add_deck).map {|s, k|
      diff = @world.diff(deck, k).map {|name, card_no, left_right| [name, card_url(card_no)] + left_right}
      link, image = DeckDetail::make_url(k)
      {
        'link' => link,
        'tweet' => refer_tw(k),
        'city' => refer_gen(k),
        'image' => image,
        'score' => s,
        'name' => k,
        'diff' => diff,
        'desc' => deck_desc(k)
      }
    }
    desc = ary.dig(0, 'desc').to_a.join(", ")
    {
      'query' => ['search_by_deck', deck],
      'desc' => "#{deck}（#{desc}）に似ているデッキ",
      'result' => ary
    }
  end

  def search_by_name(name, n=10)
    ary = @world.search_by_name(name, n).map {|s, k|
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'tweet' => refer_tw(k),
        'city' => refer_gen(k),
        'image' => image,
        'score' => s,
        'name' => k,
        'desc' => deck_desc(k)
      }
    }
    {
      'query' => ['search_by_name', name],
      'desc' => "#{name}を使ったデッキ",
      'result' => ary
    }
  end

  def search_by_card(card_no, n=10)
    ary = @world.search_by_card(card_no, n).map {|s, k|
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'tweet' => refer_tw(k),
        'city' => refer_gen(k),
        'image' => image,
        'score' => s,
        'name' => k,
        'desc' => deck_desc(k)
      }
    }
    {
      'query' => ['search_by_card', card_no],
      'desc' => "カード番号#{card_no}を使ったデッキ",
      'result' => ary
    }
  end

  def search_by_screen_name(screen_name, n=30)
    ary = @world.search_by_screen_name(screen_name, n).map {|tw|
      k = tw['deck']
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'tweet' => prepare_tw(tw),
        'city' => refer_gen(k),
        'image' => image,
        'score' => 1,
        'name' => k,
        'desc' => deck_desc(k),
      }
    }
    {
      'query' => ['search_by_screen_name', screen_name],
      'desc' => "@#{screen_name}のツイートしたデッキ",
      'result' => ary
    }
  end

  def guess_city(str)
    ary = str.split(':')
    return nil unless ary[0] == 'city'
    return nil unless ary.size == 3
    [ary[1].to_i, ary[2].to_i]
  end

  def search_city_cluster(city_index, sign)
    if (sign != @cluster_sign)
      return {
        'query' => ['search_by_city'] + city_index,
        'desc' => "データが更新されたのでリロードしてね",
        'result' => [],
        'status' => 'updated'
      }
    end

    c = @cluster[city_index[0]]
    clip = c['cluster'][city_index[1]]
    ary = c['cluster'].threshold(clip.dist * CITY_THRESHOLD, clip.index).max_by(6) {|x| x.size}.map { |x|
      s = x.size
      k = x.sample
      link, image = DeckDetail::make_url(k)
      {
        'link' => link,
        'tweet' => refer_tw(k),
        'city' => refer_gen(k),
        'image' => image,
        'score' => s,
        'name' => k,
        'desc' => deck_desc(k)
      }
    }
    head = ary[0]
    ary.each do |x|
      diff = @world.diff(ary[0]['name'], x['name']).map {|name, card_no, left_right| [name, card_url(card_no)] + left_right}
      x['diff'] = diff
    end
    {
      'query' => ['search_by_city'] + city_index,
      'desc' => "#{c['range'].first}の週の「#{DeckName.guess(@world, clip.sample)}」クラスタのようす",
      'result' => ary
    }
  end

  def add(deck)
    @world.add(deck)
  end

  def card_url(key)
    "https://www.pokemon-card.com/card-search/details.php/card/#{key}"
  end

  def guess_card_id(str)
    if /\/card\-search\/details\.php\/card\/(\d+)/ =~ str
      Integer($1, 10) rescue nil
    elsif /card_images\/.*\/(\d+)\w+\.jpg/ =~ str
      Integer($1, 10) rescue nil
    elsif /\A\/(\d+)\Z/ =~ str
      Integer($1, 10) rescue nil
    else
      Integer(str, 10) rescue nil
    end
  end

  def guess_screen_name(str)
    return nil if str.size > 16
    if /\A\/?\s*@(\w+)\s*\Z/ =~ str
      return $1
    end
    nil
  end

  def deck_desc(code)
    @world.deck_desc(code, 5)
  end

  def deck_from_google
    p :deck_from_google
    DeckFromGCS.new.search.each {|name|
      @world.add(name, true)
    }
  rescue
  end

  def deck_from_google_thread
    Thread.new do
      while true
        sleep(60)
        deck_from_google
        do_reload_recent
        @recent_updated_at = Time.now
        p :reload_recent
        sleep(3600 * 6)
      end
    end
  end

  class ForBar
    Paired12 = ['#a6cee3', '#1f78b4', '#b2df8a', '#33a02c', '#fb9a99', '#e31a1c', '#fdbf6f', '#ff7f00', '#cab2d6', '#6a3d9a', '#ffff99', '#b15928']
    PRGn11 = ['#40004b', '#762a83', '#9970ab', '#c2a5cf', '#e7d4e8', '#f7f7f7', '#d9f0d3', '#a6dba0', '#5aae61', '#1b7837', '#00441b']
    Spectral11 = ['#9e0142', '#d53e4f', '#f46d43', '#fdae61', '#fee08b', '#ffffbf', '#e6f598', '#abdda4', '#66c2a5', '#3288bd', '#5e4fa2']

    def initialize(ary)
      @ary = ary
      make_dataset
    end
    attr_reader :deck
  
    def to_chart_data
      {
        "labels" => @labels,
        "datasets" => @dataset
      }
    end
  
    def make_dataset
      dict = Hash.new {|h,k| h[k] = [0] * @ary.size}
      deck = Hash.new {|h,k| h[k] = Array.new(@ary.size)}
      other = []
      labels = []
      @ary.each_with_index do |report, i|
        labels << report['range'].first
        total = report['deck_count']
        report['cluster'].each do |c|
          dict[c[2]][i] = c[0]
          deck[c[2]][i] = [c[1], c[3]]
          total -= c[0]
        end
        other << total
      end
      dict['other'] = other
      deck['other'] = Array.new(@ary.size)
      color = Spectral11.dup
      dataset = dict.map do |k, v|
        color.rotate!
        c = color.last
        {"label" => k, "data" => v, "stack" => "stack-1", "backgroundColor" => c + "ee", "borderColor" => c}
      end
  
      @labels = labels
      @dataset = dataset.reverse
      @deck = deck.values.reverse
    end
  end  
end
