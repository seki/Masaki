require 'twitter'
require 'net/http'
require 'uri'
require 'date'
require 'open-uri'
require_relative 'deck-detail'
require_relative 'store-meta'
require_relative 'store-deck'

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
    return if tweets.empty?

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
          # MasakiPG::instance.referer_tw_store(t.to_h, x)
          Masaki::Meta.referer_tw_store(t.to_h, x)
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
  env_path = __dir__ + "/../env.rb"
  puts env_path
  load(env_path) if File.exist?(env_path)

  MyTwitter.new.search_decks {|name|
    next if Masaki::Deck.include?(name)
    p name
    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    Masaki::Deck[name] = v
  }
  puts(URI.open('https://masaki.druby.work/ping/').read)
end