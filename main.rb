require 'webrick'
require 'json'
require 'open-uri'
require_relative 'src/masaki'
require 'net/http'

port = Integer(ENV['PORT']) rescue 8000
server = WEBrick::HTTPServer.new({
  :Port => port,
  :FancyIndexing => false
})

$masaki = Masaki.new
$masaki.deck_from_twitter_thread

Dir.glob('public/*') do |path|
  server.mount('/' + File.basename(path), WEBrick::HTTPServlet::FileHandler, path)
end

server.mount_proc('/api') {|req, res|
  post = JSON.parse(req.body)
  str = post['search']
  res.content_type = "application/json; charset=UTF-8"
  it = $masaki.do_api(req, res, post).to_json
  res.body = it
}

server.mount_proc('/e/') {|req, res|
  begin
    it, type = $masaki.do_embed(req, res)
    res.content_type = type if type
    res.body = it
  rescue
    res.body = $masaki.do_get(req, res)
  end
}

server.mount_proc('/city') {|req, res|
  pp req.path_info
  res.content_type = "text/html; charset=UTF-8"
  res.body = $masaki.do_city(req, res)
}

server.mount_proc('/') {|req, res|
  pp req.path_info
  res.content_type = "text/html; charset=UTF-8"
  res.body = $masaki.do_get(req, res)
}

trap(:INT){exit!}
server.start
