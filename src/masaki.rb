require_relative 'masaki-pg'
require_relative 'deck-detail'
require_relative 'erbm'
require_relative 'world'
require 'json'

class Masaki
  include ERB::Util
  View = ERBMethod.new(self, "to_html(req, res)", 'index.html')
  EmbedView = ERBMethod.new(self, "to_embed(req, res, left, right, diff)", 'embed.html')
  def initialize
    @world = MasakiWorld.new
    @recent = @world.recent.map {|k| [k, deck_desc(k)]}
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
      'recent' => @recent
    }
  end

  def do_search_api(req, res, post)
    str = post["search"]
    filter = post["filter"] ? true : false
    add_deck = post["add"] ? true : false
    name = DeckDetail::guess_deck_name(str)
    return search(name, filter, 5, add_deck) if name
    screen_name = guess_screen_name(str)
    pp screen_name
    return search_by_screen_name(screen_name) if screen_name
    card_id = guess_card_id(str)
    return search_by_card(card_id, filter) if card_id
    search_by_name(str, filter)
  end

  def prepare_tw(tw)
    tw['url'] = "https://twitter.com/#{tw['screen_name']}/status/#{tw['id_str']}"
    tw['date'] = tw['created'].strftime("%Y年%m月%d日")
    tw['where'] = "@#{tw['screen_name']}のツイート"
    tw
  end

  def refer_tw(key)
    tw = MasakiPG::instance.referer_tw_detail(key)
    return nil unless tw
    prepare_tw(tw)
  end

  def search(deck, filter, n, add_deck)
    ary = @world.search_by_deck(deck, filter, n, add_deck).map {|s, k|
      diff = @world.diff(deck, k).map {|name, card_no, left_right| [name, card_url(card_no)] + left_right}
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'tweet' => refer_tw(k),
        'image' => image,
        'score' => s,
        'name' => k,
        'diff' => diff,
        'desc' => deck_desc(k)
      }
    }
    {
      'query' => ['search_by_deck', deck],
      'result' => ary
    }
  end

  def search_by_name(name, filter, n=10)
    ary = @world.search_by_name(name, filter, n).map {|s, k|
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'tweet' => refer_tw(k),
        'image' => image,
        'score' => s,
        'name' => k,
        'desc' => deck_desc(k)
      }
    }
    {
      'query' => ['search_by_name', name],
      'result' => ary
    }
  end

  def search_by_card(card_no, filter, n=10)
    ary = @world.search_by_card(card_no, filter, n).map {|s, k|
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'tweet' => refer_tw(k),
        'image' => image,
        'score' => s,
        'name' => k,
        'desc' => deck_desc(k)
      }
    }
    {
      'query' => ['search_by_card', card_no],
      'result' => ary
    }
  end

  def search_by_screen_name(screen_name, n=10)
    ary = @world.search_by_screen_name(screen_name, n).map {|tw|
      k = tw['deck']
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'tweet' => prepare_tw(tw),
        'image' => image,
        'score' => 1,
        'name' => k,
        'desc' => deck_desc(k)
      }
    }
    {
      'query' => ['search_by_screen_name', screen_name],
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
    else
      Integer(str, 10) rescue nil
    end
  end

  def guess_screen_name(str)
    return nil if str.size > 16
    if /\A@(\w+)\Z/ =~ str
      return $1
    end
    nil
  end

  def deck_desc(code)
    @world.top_idf(code)[0,5].map {|n| world.name(n)}
  end
end
