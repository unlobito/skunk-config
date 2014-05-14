require 'chunky_png'

module ChunkyPNG; class Image
  def to_pbi
    row_size_bytes = (self.width + 31) / 32 * 4
    info_flags = 1 << 12

    fields = [ row_size_bytes, info_flags, 0, 0, self.width, self.height ]
    data = fields.pack("S<S<s<s<s<s<")

    for y in 0...self.height do
      row = ''
      for x in 0...self.width do
        row << pixel_str(self[x, y])
      end
      data_row = [row].pack('b*')
      data_row << "\0" until (data_row.length % 4) == 0
      data << data_row
    end

    data.each_codepoint.to_a
  end

private

  def pixel_str(pixel)
    rgba = ChunkyPNG::Color.to_truecolor_alpha_bytes(pixel)
    rgba[3] < 127 || (rgba[0] + rgba[1] + rgba[2]) / 3 < 127 ? '0' : '1'
  end
end; end
