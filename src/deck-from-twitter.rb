require 'twitter_oauth'
require 'net/http'
require 'uri'
require 'date'
require_relative 'masaki-pg'
require_relative 'deck-detail'

$deck = MasakiPG::KVS.new('deck')

class Twitter
  def auth
    @twitter = TwitterOAuth::Client.new(
      :consumer_key    => ENV['TWITTER_API_KEY'],
      :consumer_secret => ENV['TWITTER_API_SECRET'],
    )
    puts "Twitter APIの認証完了"
  end

  def search_decks(num = 10, opt = {}, &blk)
    return if num <= 0
    @twitter or self.auth
    params = {
      lang:        'ja',
      locale:      'ja',
      result_type: 'mixed',
      count:       200,
    }.merge(opt)
    tweets = @twitter.search("ポケモンカードゲーム公式ホームページ デッキ", params)['statuses']
    max_id = tweets[-1]['id']
    decks = extract_decks(tweets)
    decks.each {|u|
      name = url_to_name(u)
      yield(name) if name
    }

    self.search_decks(num - 1, max_id: max_id, &blk)
  end

  def extract_decks(tweets)
    decks = tweets.map do |t|
      if urls = t['entities']['urls']
        ary = urls.map {|u| u['expanded_url']}.find_all {|x| x.include? "pokemon-card.com/deck/confirm.html/deckID"}
        ary.collect {|x| x.chomp('/')}
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
  Twitter.new.search_decks {|name|
    next if frozen.include?(name) || $deck.include?(name)
    p name
    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    $deck[name] = v.to_json
  }
end