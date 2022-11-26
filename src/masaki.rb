require_relative 'store-meta'
require_relative 'deck-detail'
require_relative 'erbm'
require_relative 'world'
require_relative 'deck-from-twitter'
require 'json'

class Masaki
  include ERB::Util
  View = ERBMethod.new(self, "to_html(req, res)", 'index.html')
  EmbedView = ERBMethod.new(self, "to_embed(req, res, left, right, diff)", 'embed.html')
  def initialize
    @world = MasakiWorld.new
    do_reload_recent
    @recent_updated_at = Time.now
  end
  attr_reader :world

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
    @recent = @world.recent.map {|k| [k, deck_desc(k)]}
  end

  def do_search_api(req, res, post)
    str = post["search"]
    add_deck = post["add"] ? true : false
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
    tw['where'] = "@#{tw['screen_name']}のツイート"
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
      'date' => date.strftime("%m月%d日") + "のシティリーグで　活躍した。"
    }
  end

  def refer_city(key)
    city = Masaki::Meta.referer_city_detail(key)
    prepare_city(city)
  end

  def search(deck, n, add_deck)
    ary = @world.search_by_deck(deck, n, add_deck).map {|s, k|
      diff = @world.diff(deck, k).map {|name, card_no, left_right| [name, card_url(card_no)] + left_right}
      link, image = DeckDetail::make_url(k)
      {
        'link' => link,
        'tweet' => refer_tw(k),
        'city' => refer_city(k),
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
        'city' => refer_city(k),
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
        'city' => refer_city(k),
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
        'city' => refer_city(k),
        'image' => image,
        'score' => 1,
        'name' => k,
        'desc' => deck_desc(k)
      }
    }
    {
      'query' => ['search_by_screen_name', screen_name],
      'desc' => "@#{screen_name}のツイートしたデッキ",
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

  def deck_from_twitter
    p :deck_from_twitter
    MyTwitter.new.search_decks {|name|
      @world.add(name, true)
    }
  rescue
  end

  def deck_from_twitter_thread
    Thread.new do
      while true
        sleep(60)
        deck_from_twitter
        do_reload_recent
        @recent_updated_at = Time.now
        p :reload_recent
        sleep(3600)
      end
    end
  end 
end
