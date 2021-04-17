require 'twitter'
require 'net/http'
require 'uri'
require 'date'
require 'open-uri'
require_relative 'masaki-pg'
require_relative 'deck-detail'

$deck = MasakiPG::KVS.new('deck')

class MyTwitter
  def auth
    @twitter = Twitter::REST::Client.new(
      :consumer_key    => ENV['TWITTER_API_KEY'],
      :consumer_secret => ENV['TWITTER_API_SECRET'],
    )
    puts "Twitter APIの認証完了"
  end

  def search_decks(num = 5, opt = {}, &blk)
    return if num <= 0
    @twitter or self.auth
    params = {
      lang:        'ja',
      locale:      'ja',
      result_type: 'recent',
      count:       200,
      tweet_mode: 'extended'
    }.merge(opt)
    tweets = @twitter.search("pokemon-card.com deck", params).to_a

    max_id = tweets[-1].id
    decks = extract_decks(tweets)
    decks.each {|name|
      yield(name) if name
    }

    sleep 2
    self.search_decks(num - 1, max_id: max_id, &blk)
  end

  def extract_decks(tweets)
    decks = tweets.map do |t|
      if urls = t.uris
        ary = urls.map {|u| u.expanded_url.to_s}.find_all {|x| x.include?("/deckID/")}
        ary = ary.collect {|x| url_to_name(x.chomp('/'))}
        ary.each do |x|
          next if x.nil?
          MasakiPG::instance.referer_tw_store(t.to_h, x)
        end
        ary
      else
        []
      end
    end
    decks.flatten.uniq
  end

  def url_to_name(url)
    name = File.basename(url)
    if /\A\w{6}-\w{6}-\w{6}\z/ =~ name
      name
    else
      nil
    end
  end
end

if __FILE__ == $0
  MasakiPG::instance.kvs_frozen_world("deck")
  frozen = MasakiPG::KVS.frozen('deck')
  MyTwitter.new.search_decks {|name|
    next if frozen.include?(name) || $deck.include?(name)
    p name
    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    $deck[name] = v.to_json
  }
  puts(URI.open('https://hamana.herokuapp.com/ping/').read)
end