require 'json'

class ForPie
  def initialize(report)
    @report = report
  end

  def to_chart_data
    total = @report['deck_count']
    data = []
    label = []
    @report['cluster'].each do |c|
      total -= c[0]
      data << c[0]
      label << [c[1], c[2]].join(' ')
    end
    label << 'other'
    data << total
    {
      'labels' => label ,
      'datasets' => [{
        'data' => data
      }]
    }.to_json
  end
end

class ForBar
  Paired12 = ['#a6cee3', '#1f78b4', '#b2df8a', '#33a02c', '#fb9a99', '#e31a1c', '#fdbf6f', '#ff7f00', '#cab2d6', '#6a3d9a', '#ffff99', '#b15928']

  def initialize(ary)
    @ary = ary
  end

  def to_chart_data
    dict = Hash.new {|h,k| h[k] = [0] * @ary.size}
    other = []
    labels = []
    @ary.each_with_index do |report, i|
      labels << (report['range'].split('.').first)
      total = report['deck_count']
      report['cluster'][0,6].each do |c|
        dict[c[2]][i] = c[0]
        total -= c[0]
      end
      other << total
    end
    dict['other'] = other
    color = Paired12.dup
    dataset = dict.map do |k, v|
      color.rotate!
      c = color.last
      {"label" => k, "data" => v, "stack" => "stack-1", "backgroundColor" => c + "ee", "borderColor" => c}
    end

    {
      "labels" => labels,
      "datasets" => dataset.reverse
    }
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

