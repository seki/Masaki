require 'webrick'
require 'json'
require 'open-uri'
require 'jwt'
require_relative 'src/masaki'
require 'net/http'

class Cognito
  def initialize
    @domain = ENV['MASAKI_COGNITO_DOMAIN'] || ENV['COGNITO_DOMAIN']
    @client_id = ENV['MASAKI_COGNITO_CLIENT_ID'] || ENV['COGNITO_CLIENT_ID']
  end

  def login_url(req)
    redirect = req.request_uri + '/'
    "#{@domain}/login?response_type=code&client_id=#{@clinet_it}&redirect_uri=#{redirect}"
  end

  def fetch_user_id(code)
    token = get_token(code)
    userinfo(token)
  end

  def userinfo(token)
    access_token = token['access_token']
    return nil unless access_token
  
    uri = URI.parse(@domain + "/oauth2/userInfo")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
  
    header = { "Authorization" => "Bearer #{access_token}" }  
    response = http.get(uri.path, header)
  
    JSON.parse(response.body)
  end
  
  def get_token(code)  
    uri = URI.parse(@domain + "/oauth2/token")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
    
    params = {
       "grant_type" => "authorization_code",
       "client_id" => @client_id,
       "code" => code,
       "redirect_uri" => "http://localhost:8000/"
    }
    response = http.post(uri.path, params.map {|k,v| [k,v].join("=")}.join('&'))
    
    JSON.parse(response.body)
  end
end

port = Integer(ENV['PORT']) rescue 8000
server = WEBrick::HTTPServer.new({
  :Port => port,
  :FancyIndexing => false
})

$cognito = Cognito.new
$masaki = Masaki.new

Dir.glob('public/*') do |path|
  server.mount('/' + File.basename(path), WEBrick::HTTPServlet::FileHandler, path)
end

server.mount_proc('/auth_config.json') {|req, res|
  res.content_type = 'application/json'
  res.body = $auth_config_json
}

server.mount_proc('/api') {|req, res|
  # value = $app.verify(req.header['authorization'])
  post = JSON.parse(req.body)
  pp post
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

server.mount_proc('/') {|req, res|
  # pp req
  code ,= req.query["code"]
  if code
    pp $cognito.fetch_user_id(code)
  end

  # puts $cognito.login_url(req)

  pp req.path_info

  res.body = $masaki.do_get(req, res)
}

trap(:INT){exit!}
server.start
