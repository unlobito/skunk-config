require 'chunky_png'
require 'json'
require 'monetize'
require 'oauth'
require 'sinatra'
require 'uri'

require './env' if File.exists? 'env.rb'
require './pbi'

use Rack::Session::Cookie, secret: ENV['COOKIE_SECRET']

helpers do
  def base_url
    scheme = request.env['rack.url_scheme']
    host = request.env['HTTP_HOST']
    "#{scheme}://#{host}"
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

def date_to_i(date)
  matches = /\/Date\((\w*)([+-]\d{4})\)\//.match(date)
  if match = matches[1]
    (match.to_i / 1000).round
  else
    -1
  end
end

def pebble_barcode(card, access_token)
  # Get the barcode.
  url = "https://api.starbucks.com/barcode/v1/mobile/payment/starbuckscard/#{card}?engine=onbarcode&height=85&width=200"
  data = access_token.get(url)

  ds = ChunkyPNG::Datastream.from_blob(data.body)
  image = ChunkyPNG::Image.from_datastream(ds)
  image.trim!
  image.resample_nearest_neighbor!(142, 8)
  image.to_pbi
end

def me_data(access_token)
  # Get the profile data.
  url = 'https://api.starbucks.com/starbucksprofile/v1/users/me'
  data = access_token.get(url, { 'Accept' => 'application/json' })
  json = JSON.parse(data.body)

  # Get the interesting card data.
  cards = json['starbucksCards'].map do |card|
    {
      balance: balance(card),
      name: card['nickname'],
      barcode_data: pebble_barcode(card['number'], access_token)
    }
  end

  {
    cards: cards
  }
end

def rewards_data(access_token)
  # Get the rewards data.
  url = 'https://api.starbucks.com/starbucksprofile/v1/users/me/rewards'
  data = access_token.get(url, { 'Accept' => 'application/json' })
  json = JSON.parse(data.body)

  threshold = json['starsThresholdForFreeDrink'].to_i
  stars_left = json['starsNeededForNextFreeDrink'].to_i

  # Get the number of stars until the threshold.
  stars = threshold - stars_left
  stars = 0 if stars < 0

  {
    updated_at: date_to_i(json['dateRetrieved']),
    stars: stars,
    drinks: json['coupons'].length,
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

get '/raw' do
  # Reconstruct the access token from the query params.
  access_token = OAuth::AccessToken.from_hash(
    consumer,
    oauth_token: params[:access_token],
    oauth_token_secret: params[:access_token_secret]
  )

  url = params[:url]
  halt 400 unless url

  request_headers = {}
  request_headers['Accept'] = 'application/json' if params[:json]

  response = access_token.get(url, request_headers)

  status response.code
  headers response.header.to_hash
  body response.body
end
