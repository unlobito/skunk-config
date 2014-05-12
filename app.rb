require 'chunky_png'
require 'erb'
require 'json'
require 'monetize'
require 'oauth'
require 'openssl'
require 'sinatra'
require 'uri'

require './env' if File.exists? 'env.rb'

use Rack::Session::Cookie, secret: ENV['COOKIE_SECRET']

helpers do
  def base_url
    @base_url ||= begin
      scheme = request.env['rack.url_scheme']
      host = request.env['HTTP_HOST']
      "#{scheme}://#{host}"
    end
  end
end

def consumer
  @consumer ||= begin
    options = {
      site: 'https://connect.starbucks.com',
      scheme: :query_string,
      http_method: :get,
      request_token_path: '/OAuth/RequestToken',
      access_token_path: '/OAuth/AccessToken',
      authorize_path: '/OAuth/AuthorizeToken',
      ca_file: 'sbux_intermediate.pem'
    }
    OAuth::Consumer.new(
      ENV['SBUX_CONSUMER_KEY'],
      ENV['SBUX_CONSUMER_SECRET'],
      options
    )
  end
end

def balance(card)
  balance = card['balance']
  currency = card['balanceCurrencyCode']
  Monetize.parse(balance, currency).format
end

def format_date(date)
  matches = /\/Date\((\w*)([+-]\d{4})\)\//.match(date)
  sec = matches[1].to_i / 1000
  tz = matches[2].insert(-3, ':')
  Time.at(sec).localtime(tz).strftime("%b %-e, %H:%M GMT%z")
end

def pixel_str(pixel)
  rgba = ChunkyPNG::Color.to_truecolor_alpha_bytes(pixel)
  rgba[3] < 127 || (rgba[0] + rgba[1] + rgba[2]) / 3 < 127 ? '0' : '1'
end

def pebble_pbi(image)
  row_size_bytes = (image.width + 31) / 32 * 4
  info_flags = 1 << 12

  fields = [ row_size_bytes, info_flags, 0, 0, image.width, image.height ]
  data = fields.pack("S<S<s<s<s<s<")

  for y in 0...image.height do
    row = ''
    for x in 0...image.width do
      row << pixel_str(image[x, y])
    end
    data << [row].pack('B*')
    data << "\0" until (data.length % 4) == 0
  end

  data.each_codepoint.to_a
end

def pebble_barcode(card, access_token)
  url = "https://api.starbucks.com/barcode/v1/mobile/payment/starbuckscard/#{card}?engine=onbarcode&height=85&width=200"
  data = access_token.get(url)

  ds = ChunkyPNG::Datastream.from_blob(data.body)
  image = ChunkyPNG::Image.from_datastream(ds)
  image.trim!
  image.resample_nearest_neighbor!(142, 64)

  pebble_pbi(image)
end

def me_data(access_token)
  url = 'https://api.starbucks.com/starbucksprofile/v1/users/me'
  data = access_token.get(url, { 'Accept' => 'application/json' })
  json = JSON.parse(data.body)

  user = json['user']
  name = "#{user['firstName']} #{user['lastName']}"

  cards = json['starbucksCards'].map do |card|
    {
      balance: balance(card),
      updated_at: format_date(card['balanceDate']),
      name: card['nickname'],
      number: card['number'],
      barcode_data: pebble_barcode(card['number'], access_token)
    }
  end

  {
    name: name,
    cards: cards
  }
end

def rewards_data(access_token)
  url = 'https://api.starbucks.com/starbucksprofile/v1/users/me/rewards'
  data = access_token.get(url, { 'Accept' => 'application/json' })
  json = JSON.parse(data.body)

  {
    updated_at: format_date(json['dateRetrieved']),
    stars_threshold: json['starsThresholdForFreeDrink'],
    stars_until_drink: json['starsNeededForNextFreeDrink'],
  }
end

get '/' do
  redirect '/login'
end

get '/login' do
  # Get a request token from Starbucks.
  callback = "#{base_url}/callback"
  request_token = consumer.get_request_token(oauth_callback: callback)

  # Store both the token and secret in the session.
  session[:request_token] = request_token.token
  session[:request_secret] = request_token.secret

  # Redirect to Starbucks for authorization.
  redirect request_token.authorize_url(oauth_callback: callback)
end

get '/callback' do
  # Get the token and secret we stored in the session.
  token = session[:request_token]
  secret = session[:request_secret]

  # If we don't have both, someone done goofed.
  halt 400 unless token and secret
  session[:request_token] = session[:request_secret] = nil

  # Reconstruct the request token.
  request_token = OAuth::RequestToken.from_hash(
    consumer,
    oauth_token: token,
    oauth_token_secret: secret
  )

  # Get the access token from the request token and the query params.
  verifier = params[:oauth_verifier]
  access_token = request_token.get_access_token(oauth_verifier: verifier)

  # Construct the response data, and go.
  data = {
    access_token: access_token.token,
    access_token_secret: access_token.secret,
  }
  fragment = URI.encode_www_form(data)
  url = URI::Generic.build(scheme: 'pebblejs', host: 'close', fragment: fragment)
  redirect url.to_s
end

get '/data' do
  # Reconstruct the access token from the query params.
  access_token = OAuth::AccessToken.from_hash(
    consumer,
    oauth_token: params[:access_token],
    oauth_token_secret: params[:access_token_secret]
  )

  begin
    response_data = me_data(access_token)
    response_data['rewards'] = rewards_data(access_token)

    content_type :json
    JSON.generate(response_data)
  rescue
    halt 400
  end
end
