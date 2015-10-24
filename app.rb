require 'chunky_png'
require 'json'
require 'net/http'
require 'sinatra'
require 'uri'

require 'barby'
require 'barby/barcode/qr_code'
require 'barby/barcode/ean_8'
require 'barby/barcode/ean_13'
require 'barby/outputter/png_outputter'

require 'rghost'
require 'rghost_barcode'

require 'zxing'

require './env' if File.exists? 'env.rb'
require './xbi'

use Rack::Session::Cookie, secret: ENV['COOKIE_SECRET']

$banned_resize = ["upca", "qrcode", "pdf417", "code39", "code128", "ean13", "ean8", "rationalizedCodabar", "interleaved2of5"]
$linear_formats = ["code39", "code128", "ean8", "ean13", "upca", "rationalizedCodabar", "interleaved2of5"]

def pebble_barcode(type, card)
  maxpixelcount = (256-3)*8

  if type == "qrcode"
    barcode = Barby::QrCode.new(card, {:level => :l})
    barcode_png = barcode.to_png
  elsif $linear_formats.any? { |s| type.include?(s) }
    doc=RGhost::Document.new
    doc.send(("barcode_"+type).to_sym, card, {:scale => [1,1]})

    barcode_png = doc.render_stream :png
  elsif type == "pdf417"
    doc=RGhost::Document.new
    doc.barcode_pdf417 card, {:columns => 2, :rows => 3, :compact => true, :eclevel => 1}

    barcode_png = doc.render_stream :png
  else
    doc=RGhost::Document.new
    doc.send(("barcode_"+type).to_sym, card, {:x=> 1, :y => 1, :scale => [5,5]})

    barcode_png = doc.render_stream :png
  end

  ds = ChunkyPNG::Datastream.from_blob(barcode_png)
  image = ChunkyPNG::Image.from_datastream(ds)

  # Trim the whitespace
  image.trim!

  # Resize
  if !$banned_resize.any? { |s| type.include?(s) }
    width = (40 * image.width / image.height)
    height = 40

    if width >= 65
      width = 65
      height = (65 * image.height / image.width)
    end

    image.resample_nearest_neighbor!(width, height)
  end

  if type == "pdf417"
    height = maxpixelcount / image.width

    image.resample_nearest_neighbor!(image.width, height)
  end

  # Convert to .pbi format
  if !$linear_formats.any? { |s| type.include?(s) }
    image.to_xbi
  else
    image.to_xbi true
  end
end

def cards_data(cards)
  cards.map do |card|
    if $linear_formats.any? { |s| card['type'].include?(s) }
      {
        name: card['name'],
        barcode_data: pebble_barcode(card['type'], card['data']),
        value: card['data']
      }
    else
      {
        name: card['name'],
        barcode_data: pebble_barcode(card['type'], card['data'])
      }
    end
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

post '/decode' do
  uploaded_file = params[:image][:tempfile]

  ZXing.decode! uploaded_file

end
