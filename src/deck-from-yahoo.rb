require 'uri'
require 'open-uri'
require 'json'
require_relative 'store-meta'

class DeckFromYahoo
  def initialize()
    @uri = URI.parse('https://search.yahoo.co.jp/realtime/api/v1/pagination?')
  end

  def search
    decks = []
    search_loop do |deck, id_str, created_at, screen_name|
      pp deck
      decks << deck
      now = Masaki::Meta.as_time(Time.now)
      Masaki::Meta.do_referer_tw_store(deck, id_str, Masaki::Meta.as_time(created_at), screen_name)
      Masaki::Meta.referer_all_store(deck, now)      
    end
    decks
  end

  def make_query(query)
    ary = query.map {|k,v| [k, v]}
    uri = @uri.dup
    uri.query = URI.encode_www_form(ary)
    uri
  end

  def search_one(start=nil)
    query = {
      'p' => 'https://www.pokemon-card.com/deck/',
      'results' => '40'
    }
    query['oldestTweetId'] = start if start
    uri = make_query(query)
    json = uri.open(
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      "Accept" => "application/json, text/plain, */*",
      "Referer" => "https://search.yahoo.co.jp/realtime/search").read
    JSON.parse(json)
  rescue
    nil
  end

  def url_to_name(url)
    name = File.basename(url.chomp('/'))
    if /\A\w{6}-\w{6}-\w{6}\z/ =~ name
      name
    else
      nil
    end
  end

  def each_tw(list, &proc)
    ary = list['timeline']['entry'] rescue []
    ary.each do |tw|
      url = tw['urls'].map {|y| y['expandedUrl'].to_s}.find_all {|z| z.include?("/deckID/")}
      deck = url.map {|x| url_to_name(x)}.uniq.compact
      screen_name = tw['screenName']
      id_str = tw['id']
      created_at = Time.at(tw['createdAt'])
      deck.each do |d|
        yield(d, id_str, created_at, screen_name)
      end
    end
  end

  def search_loop(&proc)
    list = search_one()
    while list
      each_tw(list, &proc)
      last = list['timeline']['entry'].last['id'] rescue nil
      break unless last
      list = search_one(last)
    end
  end
end

if __FILE__ == $0
  load '../env.rb'
  it = DeckFromYahoo.new
  found = it.search
  pp found
end

