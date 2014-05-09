require 'sinatra'
require 'oauth'
require './env' if File.exists? 'env.rb'

enable :sessions

use Rack::Session::Cookie, secret: ENV['COOKIE_SECRET']

helpers do
  def base_url
    @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
  end

  def consumer
    @consumer ||= OAuth::Consumer.new(ENV['SBUX_CONSUMER_KEY'], ENV['SBUX_CONSUMER_SECRET'], {
      site: 'https://connect.starbucks.com',
      scheme: :query_string,
      http_method: :get,
      request_token_path: '/OAuth/RequestToken',
      access_token_path: '/OAuth/AccessToken',
      authorize_path: '/OAuth/AuthorizeToken',
    })
  end
end

get '/' do
  'Whee!'
end

get '/login' do
  request_token = consumer.get_request_token(oauth_callback: "#{base_url}/callback")
  session[:request_token] = request_token
  redirect request_token.authorize_url
end

get '/callback' do
  request_token = session[:request_token]
  consumer.get_access_token request_token
end