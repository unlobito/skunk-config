require 'chunky_png'
require 'json'
require 'net/http'
require 'sinatra'
require 'uri'

require 'barby'
require 'barby/barcode/qr_code'
require 'barby/barcode/ean_13'
require 'barby/outputter/png_outputter'

require 'rghost'
require 'rghost_barcode'

require 'pdf417'

require './env' if File.exists? 'env.rb'
require './xbi'

use Rack::Session::Cookie, secret: ENV['COOKIE_SECRET']

def pebble_barcode(type, card)
  if type == "qrcode"
    barcode = Barby::QrCode.new(card, {:size => 6, :level => "l"})
    barcode_png = barcode.to_png
  elsif type == "upca"
    barcode = Barby::EAN13.new(card)
    barcode_png = barcode.to_png
  else
    doc=RGhost::Document.new
    doc.send(("barcode_"+type).to_sym, card, {:x=> 1, :y => 1, :scale => [5,5]})

    barcode_png = doc.render_stream :png
  end

  ds = ChunkyPNG::Datastream.from_blob(barcode_png)
  image = ChunkyPNG::Image.from_datastream(ds)

  # Trim the whitespace
  image.trim!

  width = (40 * image.width / image.height)
  height = 40

  if width >= 65
    width = 65
    height = (65 * image.height / image.width)
  end

  # Resize
  if type != "upca" && type != "qrcode"
    image.resample_bilinear!(width, height)
  end

  # Convert to .pbi format
  if type != "upca"
    image.to_xbi
  else
    image.to_xbi true
  end
end

def cards_data(cards)
  cards.map do |card|
    {
      name: card['name'],
      barcode_data: pebble_barcode(card['type'], card['data'])
    }
  end
end

get '/' do
  redirect '/settings'
end

get '/settings' do
  erb :settings, locals: { }
end

post '/data' do
  incoming_data = JSON.parse(request.body.read)

  content_type :json
  JSON.generate({
    cards: cards_data(incoming_data['barcodes'])
  })
end
