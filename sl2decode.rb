require 'yaml'

# Constants:
POLAR_EARTH_RADIUS = 6356752.3142
PI = Math::PI

if ARGV[0].to_s==''
  puts "Usage: ruby sl2decode.rb your_file.sl2"
  exit
end

# Read given sl2 file:
f=File.open(ARGV[0], 'rb')
s=f.read(); "#{s.length} Bytes read"
f.close

output = []

block_offset=0

# 10 Bytes Header
block_offset+=10   # Startindex des ersten Blocks

# Datentypen:
# ===================================================================================================
# Typ     Definition                                          Direktive für Ruby's String#unpack
# ---------------------------------------------------------------------------------------------------
# byte 	  UInt8                                                C
# short 	UInt16LE                                             v
# int 	  UInt32LE                                             V
# float 	FloatLE (32 bits IEEE 754 floating point number)     e (od. E?)
# flags 	UInt16LE                                             v
# ---------------------------------------------------------------------------------------------------


block_def = {
  'blockSize' => {:offset=>26, :type=>'v'},
#  'lastBlockSize' => {:offset=>28, :type=>'v'},
#  'channel' => {:offset=>30, :type=>'v'},
#  'packetSize' => {:offset=>32, :type=>'v'},
#  'frameIndex' => {:offset=>34, :type=>'V'},
#  'upperLimit' => {:offset=>38, :type=>'e'},
#  'lowerLimit' => {:offset=>42, :type=>'e'},
#  'frequency' => {:offset=>51, :type=>'C'},
  'waterDepth ' => {:offset=>62, :type=>'e'},   # in feet
#  'keelDepth ' => {:offset=>66, :type=>'e'},    # in feet
#  'speedGps' => {:offset=>98, :type=>'e'},      # in knots
  'temperature' => {:offset=>102, :type=>'e'},  # in °C
  'lowrance_longitude' => {:offset=>106, :type=>'V'},    # Lowrance encoding (easting)
  'lowrance_latitude' => {:offset=>110, :type=>'V'},     # Lowrance encoding (northing)
#  'speedWater' => {:offset=>114, :type=>'e'},   # Wassergeschwindigkeit (Messrad falls vorhanden, sonst GPS Wert)
#  'courseOverGround' => {:offset=>118, :type=>'e'},  # ourseOverGround in radians
#  'altitude ' => {:offset=>122, :type=>'e'},    # in feet
#  'heading' => {:offset=>126, :type=>'e'},      # in radians
#  'flags' => {:offset=>130, :type=>'v'},
#  'time' => {:offset=>140, :type=>'V'}          # unknown resolution, unknown epoche
}


while block_offset<s.length do
  h={}
  block_def.each do |key,bdef|
    h[key] = s[block_offset+bdef[:offset], block_offset+bdef[:offset]+4].unpack(bdef[:type]).first
  end
  # Verschiedene Konvertierungen:
  h['longitude'] = h['lowrance_longitude']/POLAR_EARTH_RADIUS * (180/PI)
  h['latitude'] = ((2*Math.atan(Math.exp(h['lowrance_latitude']/POLAR_EARTH_RADIUS)))-(PI/2)) * (180/PI)
  begin
    block_offset += h['blockSize']
  rescue 
    raise h.inspect
  end
  output << h.dup
end; puts "Found and decoded #{output.length} data blocks."

f=File.open('sl2_to_hash_output.txt', 'w')
f.puts("Found #{output.length} blocks.")
f.puts(output.inspect);
f.puts('--------------- YAML ------------------')
f.puts(output.to_yaml);
f.close

