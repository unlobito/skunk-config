require 'chunky_png'

module ChunkyPNG
  class Image
    def to_xbi(flatBarcode = false)
      maxpixelcount = (256-3)*8

      # 0x00 defines whether the image is a linear or 2D barcode
      if !flatBarcode
        data = [0, self.width, self.height].pack("C*")
        pixels = self.height*self.width
      else
        data = [1, self.width, self.height].pack("C*")
        pixels = self.width
      end

      bit_data = ''

      x = 0
      y = 0

      for i in 0...pixels do
        if i+1 > maxpixelcount
          break
        end

        bit_data << pixel_str(self[x, y])

        x = x + 1
        if x == self.width then
          x = 0
          y = y + 1
        end
      end

      # pad bit_data to ensure it will nicely fit when converted to binary proper
      if bit_data.length % 8 != 0
        for i in 1...bit_data.length % 8 do
          bit_data << '0'
        end
      end

      bit = bit_data.scan(/.{8}/)

      for i in 0...bit.length do
        data << [bit[i]].pack('b*')
      end

      data.each_codepoint.to_a
    end

  private

    def pixel_str(pixel)
      rgba = ChunkyPNG::Color.to_truecolor_alpha_bytes(pixel)
      rgba[3] < 127 || (rgba[0] + rgba[1] + rgba[2]) / 3 < 127 ? '1' : '0'
    end
  end
end
