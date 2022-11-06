require 'open-uri'
require 'json'

module Masaki
  module Players
    module_function
    def fetch_event_list(last='20221001')
      offset = 0
      list = []
      while true
        chunk = fetch_event_list_1(offset)
        list += chunk['event']
        offset += 20
        break if list[-1]['event_date_params'] <= last
        break if chunk['eventCount'] <= offset
      end
      list
    end

    def fetch_event_list_1(offset)
      url = "https://players.pokemon-card.com/event_search?offset=#{offset}&order=4&result_resist=1&event_type[]=3:1&event_type[]=3:2&event_type[]=3:7"
      URI.open(url) do |x|
        return JSON.parse(x.read)
      end
    rescue OpenURI::HTTPError
      pp [:retry_open_uri, key]
      sleep 5
      retry
    end

    def fetch_result_page(key)
      name = "https://players.pokemon-card.com/event_result_detail_search?event_holding_id=#{key}&offset=0"
      URI.open(name) do |x|
        return x.read
      end
    rescue OpenURI::HTTPError
      pp [:retry_open_uri, key]
      sleep 5
      retry
    end

    def parse(event)
      date = Date.parse(event.dig('event', 'eventDate', 'date' )).to_s
      event['results'].map do |x|
        deck = x['deck_id']
        deck ? [deck, date] : nil
      end.compact
    end
  end
end

if __FILE__ == $0
  if fname = ARGV.shift
    city = JSON.parse(File.read(fname))
  else
    city = Masaki::Players::fetch_event_list('20221021').find_all {|x|
      x['event_title'].start_with?("シティリーグ2023 シーズン1")
    }
    File.write("city_2022_10.json", city.to_json)
  end
  if fname = ARGV.shift
    events = JSON.parse(File.read(fname))
  else
    keys = city.map {|x| x['event_holding_id']}
    events = keys.map do |key|
      page = Masaki::Players::fetch_result_page(key)
      JSON.parse(page)
    end
  end

  decks = []
  events.each do |ev|
    decks += Masaki::Players::parse(ev)
  end

  File.write('city-deck-202210.json', decks.to_json)
end

