require 'chunky_png'
require 'json'
require 'monetize'
require 'net/http'
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

def track_analytics(endpoint, pebble_id, version)
  params = {
    'v' => '1',
    'tid' => ENV['GOOGLE_ANALYTICS_ID'],
    'cid' => pebble_id || 'UNKNOWN',
    't' => 'screenview',
    'an' => ENV['PEBBLE_APP_NAME'],
    'aid' => ENV['PEBBLE_APP_ID'],
    'av' => version || 'UNKNOWN',
    'cd' => endpoint,
  }
  Net::HTTP.post_form URI('http://www.google-analytics.com/collect'), params
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

# Format the card's balance
def balance(card)
  balance = card['balance']
  currency = card['balanceCurrencyCode']
  Monetize.parse(balance, currency).format
end

# Convert a Starbucks "date" into a UNIX timestamp.
def date_to_i(date)
  matches = /\/Date\((\w*)([+-]\d{4})\)\//.match(date)
  if matches && match = matches[1]
    (match.to_i / 1000).round
  else
    -1
  end
end

def pebble_barcode(card, access_token)
  # Get the barcode
  url = "https://api.starbucks.com/barcode/v1/mobile/payment/starbuckscard/" + \
    "#{card}?engine=onbarcode&height=85&width=200"
  data = access_token.get(url)

  ds = ChunkyPNG::Datastream.from_blob(data.body)
  image = ChunkyPNG::Image.from_datastream(ds)

  # Trim the whitespace
  image.trim!

  # Resize
  image.resample_nearest_neighbor!(142, 8)

  # Convert to .pbi format
  image.to_pbi
end

def me_data(access_token)
  # Get the profile data
  url = 'https://api.starbucks.com/starbucksprofile/v1/users/me'
  response = access_token.get(url, { 'Accept' => 'application/json' })

  # Try to parse the result JSON
  begin
    json = JSON.parse(response.body)
  rescue JSON::ParserError => e
    halt response.code.to_i
  end

  # Get the interesting card data
  cards = json['starbucksCards']
  cards = [] unless cards
  cards.map! do |card|
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
  # Get the rewards data
  url = 'https://api.starbucks.com/starbucksprofile/v1/users/me/rewards'
  response = access_token.get(url, { 'Accept' => 'application/json' })

  # Try to parse the result JSON
  begin
    json = JSON.parse(response.body)
  rescue JSON::ParserError => e
    halt response.code.to_i
  end

  stars_left = json['starsNeededForNextFreeDrink'].to_i

  if stars_left >= 0
    # Get the threshold (should be 12)
    threshold = json['starsThresholdForFreeDrink'].to_i

    # Get the number of stars until the threshold
    stars = threshold - stars_left
    stars = 0 if stars < 0
  else
    # User doesn't receive free drinks at theshold. Show star total
    stars = json['totalPoints'].to_i
  end

  coupons = json['coupons']
  coupons = [] unless coupons

  # Form the result data
  {
    updated_at: date_to_i(json['dateRetrieved']),
    stars: stars,
    drinks: coupons.length,
  }
end

before do
  if pebble_id = params[:pebble] && version = params[:version]
    track_analytics(request.path_info, pebble_id, version)
  end
end

get '/' do
  redirect '/login'
end

get '/login' do
  # Get a request token from Starbucks
  callback = "#{base_url}/callback"
  request_token = consumer.get_request_token(oauth_callback: callback)

  # Store both the token and secret in the session
  session[:request_token] = request_token.token
  session[:request_secret] = request_token.secret

  # Redirect to Starbucks for authorization
  redirect request_token.authorize_url(oauth_callback: callback)
end

get '/callback' do
  # Get the token and secret we stored in the session
  token = session[:request_token]
  secret = session[:request_secret]

  # If we don't have both, someone done goofed
  halt 400 unless token and secret
  session[:request_token] = session[:request_secret] = nil

  # Reconstruct the request token
  request_token = OAuth::RequestToken.from_hash(
    consumer,
    oauth_token: token,
    oauth_token_secret: secret
  )

  # Get the access token from the request token and the query params
  verifier = params[:oauth_verifier]
  access_token = request_token.get_access_token(oauth_verifier: verifier)

  # Construct the response data, and go
  data = {
    access_token: access_token.token,
    access_token_secret: access_token.secret,
  }
  fragment = URI.encode_www_form(data)

  # Form the URL
  url = URI::Generic.build(
    scheme: 'pebblejs',
    host: 'close',
    fragment: fragment
  )

  # Redirect to "pebblejs://close#..."
  redirect url.to_s
end

post '/data' do
  # Reconstruct the access token from the query params
  access_token = OAuth::AccessToken.from_hash(
    consumer,
    oauth_token: params[:access_token],
    oauth_token_secret: params[:access_token_secret]
  )

  response_data = me_data(access_token)
  response_data['rewards'] = rewards_data(access_token)

  content_type :json
  JSON.generate(response_data)
end

post '/raw' do
  # If we don't have both, someone done goofed
  halt 401 unless params[:access_token] && params[:access_token_secret]

  # Reconstruct the access token from the query params
  access_token = OAuth::AccessToken.from_hash(
    consumer,
    oauth_token: params[:access_token],
    oauth_token_secret: params[:access_token_secret]
  )

  # Get the request URL
  url = params[:url]
  halt 400 unless url

  # Make the request
  response = access_token.get(url, { 'Accept' => 'application/json' })

  # Return the results
  status response.code
  headers response.header.to_hash
  body response.body
end
