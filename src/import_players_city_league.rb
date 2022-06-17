require 'nokogiri'
require 'open-uri'
require 'json'

module Masaki
  module Players
    module_function
    def fetch_result_page(key)
      name = "https://event.pokemon-card.com/prior-reception-gym-events/#{key}/"
      URI.open(name) do |x|
        raise("not found") unless x.base_uri.to_s == name
        return x.read
      end
    rescue OpenURI::HTTPError
      pp [:retry_open_uri, key]
      sleep 5
      retry
    end

    def parse(page, dict)
      doc = Nokogiri.HTML5(page)
      ary = doc.css('.eventResult__listArea').map do |list|
        parse_list(list, dict)
      end
      title = doc.at_css('.eventDetailMainVisual__infoAreaTitle').text
      [title, ary]
    end

    def parse_list(list, dict)
      head = parse_head(list)
      ary = list.css('.eventResult__listBoxRow').map do |row|
        result = row.at_css('.eventResult__listBoxItemNumber').text.to_i
        player = row.at_css('.eventResult__listBoxItemUserName').text
        deck = row.at_css('.eventResult__listBoxItemBtnArea input')['value'] rescue nil
        dict[deck] << head[:date] if deck
        [result, player, deck]
      end
      return head, ary.find_all {|x| x[2]}
    end

    def parse_head(head)
      area = head.css('.eventResult__listBoxEventArea').text
      hall = head.css('.eventResult__listBoxEventHall').text
      date = head.css('.eventResult__listBoxEventDate').text
      if /(\d\d\d\d)年(\d\d)月(\d\d)日/ =~ date
        date = [$1, $2, $3].join('-')
      end
      { :area => area, :hall => hall, :date => date}      
    end

    def city_reverse(city)
      city.each do |c|
        title, *event = c
        event.each do |e|
          head, *list = e
          list.each do |row|
            yield([row[2], head[:date] || head['date'], title])
          end
        end
      end
    end
  end
end

if __FILE__ == $0
  dict = Hash.new {|h, k| h[k] = []}
  keys = [
    [877, 881, 882, 921, 924, 925], 
    (985..987),
    (1052..1054),
    (1108..1110),
    (1184..1186),
    (1201..1203),
    (1269..1271)
  ].map(&:to_a).flatten
  city = keys.map do |key|
    page = Masaki::Players::fetch_result_page(key)
    Masaki::Players::parse(page, dict)
  end

  # File.write('city-detail.json', JSON.pretty_generate(city))
  File.write('city-deck.json', dict.to_json)
end

# page = Masaki::Players::fetch_result_page
# puts page
