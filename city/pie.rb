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

if __FILE__ == $0
  rough = JSON.parse(File.read('report_rough.json'))
  detail = JSON.parse(File.read('report_detail.json'))

  fp = ForPie.new(detail[-2])
  puts fp.to_chart_data
end

