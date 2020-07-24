require 'webrick'
require 'json'
require 'open-uri'
require 'jwt'
require_relative 'src/masaki'

class Auth0App
  def initialize(conf)
    @conf = conf
  end

  def load_jwt_keys
    body = URI.open("https://#{@conf["domain"]}/.well-known/jwks.json").read
    @pub_key = {}
    JSON.parse(body)['keys'].each do |key|
      @pub_key[key['kid']] = OpenSSL::X509::Certificate.new(
        Base64.decode64(key['x5c'].first)
      ).public_key
    end
  end

  def pub_key(kid)
    unless @pub_key
      load_jwt_keys
    end
    @pub_key[kid]
  end

  def do_verify(token)
    JWT.decode(token, nil, true, 
      algorithm: 'RS256',
      iss: "https://#{@conf["domain"]}/",
      verify_iss: true,
      aud: @conf['audience'],
      verify_aud: true
    ) { |header|
      pub_key(header['kid'])
    }
  end

  def verify(str)
    str = str.dig(0)
    if /\ABearer\s+(.*)\z/ =~ str
      jwt = do_verify($1).first
      raise "expired" unless (jwt['iat'] .. jwt['exp']) === Time.now.to_i
      jwt
    else
      raise "invalid"
    end
  end
end

port = Integer(ENV['PORT']) rescue 8000
server = WEBrick::HTTPServer.new({
  :Port => port,
  :FancyIndexing => false
})

$auth_config = {
  "domain" => ENV['AUTH0_DOMAIN'],
  "clientId" => ENV['AUTH0_CLIENT_ID'],
  "audience" => ENV['AUTH0_AUDIENCE']
}
$auth_config_json = $auth_config.to_json
# $app = MyApp.new($auth_config)
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
  res.body = $masaki.do_get(req, res)
}

trap(:INT){exit!}
server.start
