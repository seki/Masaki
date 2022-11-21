require 'json'

class ForBar
  Paired12 = ['#a6cee3', '#1f78b4', '#b2df8a', '#33a02c', '#fb9a99', '#e31a1c', '#fdbf6f', '#ff7f00', '#cab2d6', '#6a3d9a', '#ffff99', '#b15928']

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
      labels << (report['range'].split('.').first)
      total = report['deck_count']
      report['cluster'][0,8].each do |c|
        dict[c[2]][i] = c[0]
        deck[c[2]][i] = c[1]
        total -= c[0]
      end
      other << total
    end
    dict['other'] = other
    deck['other'] = Array.new(@ary.size)
    color = Paired12.dup
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

if __FILE__ == $0
  rough = JSON.parse(File.read('report_rough.json'))
  detail = JSON.parse(File.read('report_detail.json'))

  # fp = ForPie.new(detail[-2])
  # puts fp.to_chart_data
  fb = ForBar.new(rough)
  puts fb.to_chart_data.to_json
end

