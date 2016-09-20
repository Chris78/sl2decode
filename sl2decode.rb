require 'yaml'

# Constants:
POLAR_EARTH_RADIUS = 6356752.3142
PI = Math::PI
FT2M = 1/3.2808399  # factor for feet to meter conversions
KN2KM = 1/1.852     # factor for knots to km conversions

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
block_offset+=10   # Startindex of the first block

# Datentypen:
# ===================================================================================================
# Type    Definition                                          Directive for Ruby's String#unpack
# ---------------------------------------------------------------------------------------------------
# byte 	  UInt8                                               C
# short   UInt16LE                                            v
# int 	  UInt32LE                                            V
# float   FloatLE (32 bits IEEE 754 floating point number)    e
# flags   UInt16LE                                            v
# ---------------------------------------------------------------------------------------------------

# Available block attributes, their offset inside each block and their type: 
block_def = {
  'blockSize' => {:offset=>26, :type=>'v'},
#  'lastBlockSize' => {:offset=>28, :type=>'v'},
#  'channel' => {:offset=>30, :type=>'v'},
#  'packetSize' => {:offset=>32, :type=>'v'},
#  'frameIndex' => {:offset=>34, :type=>'V'},
#  'upperLimit' => {:offset=>38, :type=>'e'},
#  'lowerLimit' => {:offset=>42, :type=>'e'},
#  'frequency' => {:offset=>51, :type=>'C'},
  'time1' => {:offset=>58, :type=>'V'},
  'waterDepthFt' => {:offset=>62, :type=>'e'},    # in feet
#  'keelDepthFt' => {:offset=>66, :type=>'e'},    # in feet
#  'speedGpsKnots' => {:offset=>98, :type=>'e'},  # in knots
  'temperature' => {:offset=>102, :type=>'e'},    # in °C
  'lowrance_longitude' => {:offset=>106, :type=>'V'},    # Lowrance encoding (easting)
  'lowrance_latitude' => {:offset=>110, :type=>'V'},     # Lowrance encoding (northing)
#  'speedWaterKnots' => {:offset=>114, :type=>'e'},   # from "water wheel sensor" if present, else GPS value(?)
#  'courseOverGround' => {:offset=>118, :type=>'e'},  # courseOverGround in radians
#  'altitudeFt' => {:offset=>122, :type=>'e'},   # in feet
#  'heading' => {:offset=>126, :type=>'e'},      # in radians
   'flags' => {:offset=>130, :type=>'v'},
  'time' => {:offset=>138, :type=>'V'}          # unknown resolution, unknown epoche (probably seconds since beginning of day 
}


while output.length<20 && block_offset<s.length do
  h={}
  block_def.each do |key,bdef|
    h[key] = s[block_offset+bdef[:offset], block_offset+bdef[:offset]+4].unpack(bdef[:type]).first
  end
  # Some Conversions into non proprietary formats:
  h['longitude'] = h['lowrance_longitude']/POLAR_EARTH_RADIUS * (180/PI) if h.has_key?('lowrance_longitude')
  h['latitude'] = ((2*Math.atan(Math.exp(h['lowrance_latitude']/POLAR_EARTH_RADIUS)))-(PI/2)) * (180/PI) if h.has_key?('lowrance_latitude')
  h['waterDepthM'] = h['waterDepthFt'] * FT2M if h.has_key?('waterDepthFt')
  h['keelDepthM']  = h['keelDepthFt'] * FT2M if h.has_key?('keelDepthFt')
  h['altitudeM']   = h['altitudeFt'] * FT2M if h.has_key?('altitudeFt')
  h['speedGpsKm']  = h['speedGpsKnots'] * KN2KM if h.has_key?('speedGpsKnots')
  begin
    block_offset += h['blockSize']
  rescue 
    raise h.inspect
  end
  output << h.dup
end; puts "Found and decoded #{output.length} data blocks."

puts output.to_yaml
exit

f=File.open("#{ARGV[0]}_output.csv", 'w')
output2=output.map{|x| {'latitude'=>x['latitude'], 'longitude'=>x['longitude'], 'waterDepthM'=>x['waterDepthM']}}
output2.group_by{|x| [x['latitude'],x['longitude']]}.each do |ll,data|
  avg_depth = 0
  data.map{|y| y['waterDepthM']}.each{|summand| avg_depth+=summand}
  avg_depth = avg_depth / data.length
  f.puts [ll[0], ll[1], avg_depth].join(';')
end

#f.puts("Found #{output.length} blocks.")
#f.puts(output.inspect);
#f.puts('--------------- YAML ------------------')
#f.puts(output.to_yaml);
f.close

