require 'google/apis/customsearch_v1'
require_relative 'store-meta'

class DeckFromGCS
  def initialize(api_key=nil, cx=nil)
    api_key ||= ENV['GOOGLE_API_KEY']
    @cx ||= ENV['SEARCH_ENGINE']
    pp [api_key, @cx]

    @searcher = Google::Apis::CustomsearchV1::CustomSearchAPIService.new
    @searcher.key = api_key
  end

  def search
    decks = []
    10.times do |n|
      r = search_one(n * 10)
      links = r.items.map {|x| x.link}
      decks += links
      break if links.size < 10
    end
    decks = decks.map {|x| /\w{6}-\w{6}-\w{6}/.match(x).to_s}.uniq
    date = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
    decks.each do |x|
      Masaki::Meta.referer_google_store(x, date)
      Masaki::Meta.referer_all_store(x, date)
    end
    decks
  end

  def search_one(start=1)
    @searcher.list_cses(
      cx: @cx,
      q: "allinurl:https://www.pokemon-card.com/deck/ deckID",
      lr: 'lang_ja',
      date_restrict: 'w1',
      search_type: 'image',
      start: start
    )
  end
end

if __FILE__ == $0
  load '../env.rb'
  it = DeckFromGCS.new
  found = it.search
  pp found
end

