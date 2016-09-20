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
#f=File.open(ARGV[0], 'rb')
#s=f.read(); "#{s.length} Bytes read"
#f.close

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
  'blockSize' => {:offset=>26, :type=>'v', :len=>2},
#  'lastBlockSize' => {:offset=>28, :type=>'v', :len=>2},
#  'channel' => {:offset=>30, :type=>'v', :len=>2},
#  'packetSize' => {:offset=>32, :type=>'v', :len=>2},
#  'frameIndex' => {:offset=>34, :type=>'V', :len=>4},
#  'upperLimit' => {:offset=>38, :type=>'e', :len=>4},
#  'lowerLimit' => {:offset=>42, :type=>'e', :len=>4},
#  'frequency' => {:offset=>51, :type=>'C', :len=>1},
#  'time1' => {:offset=>58, :type=>'V', :len=>4}          # unknown resolution, unknown epoche
  'waterDepthFt' => {:offset=>62, :type=>'e', :len=>4},    # in feet
#  'keelDepthFt' => {:offset=>66, :type=>'e', :len=>4},    # in feet
#  'speedGpsKnots' => {:offset=>98, :type=>'e', :len=>4},  # in knots
#  'temperature' => {:offset=>102, :type=>'e', :len=>4},    # in °C
  'lowrance_longitude' => {:offset=>106, :type=>'V', :len=>4},    # Lowrance encoding (easting)
  'lowrance_latitude' => {:offset=>110, :type=>'V', :len=>4},     # Lowrance encoding (northing)
#  'speedWaterKnots' => {:offset=>114, :type=>'e', :len=>4},   # from "water wheel sensor" if present, else GPS value(?)
#  'courseOverGround' => {:offset=>118, :type=>'e', :len=>4},  # ourseOverGround in radians
#  'altitudeFt' => {:offset=>122, :type=>'e', :len=>4},   # in feet
#  'heading' => {:offset=>126, :type=>'e', :len=>4},      # in radians
#  'flags' => {:offset=>130, :type=>'v', :len=>2},
#  'time' => {:offset=>138, :type=>'V', :len=>4}          # unknown resolution, unknown epoche
}

f_raw = File.open("#{ARGV[0]}_output_raw.csv",'w')

begin
output = []
output_h = {}

open ARGV[0], 'r' do |f|
#  f.seek 10 # Header
#  s = f.read 32
#end

while block_offset<File.size(ARGV[0]) do
  h={}
  #b_sz = h['blockSize'] = s[block_offset+block_def['blockSize'][:offset], block_offset+block_def['blockSize'][:offset]+block_def['blockSize'][:len]].unpack(block_def['blockSize'][:type]).first
	#f.seek(block_offset+block_def['blockSize'][:offset])
	#b_sz = h['blockSize'] = f.read(block_def['blockSize'][:offset]+block_def['blockSize'][:len]].unpack(block_def['blockSize'][:type]).first
	#ss = s[block_offset, block_offset+b_sz]
  block_def.each do |key,bdef|
    f.seek(block_offset+bdef[:offset])
    h[key] = f.read(bdef[:len]).unpack(bdef[:type]).first
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
  #output << h.dup
  unless output_h[[h['latitude'], h['longitude']]]
  output_h[[h['latitude'], h['longitude']]] = h['waterDepthM']
    #f_raw.puts([h['longitude'], h['latitude'], h['waterDepthM']].join(';').gsub('.',','))
    f_raw.puts([h['longitude'], h['latitude'], h['waterDepthM']].join(' ')+';')
  end
end; 
#puts "Found and decoded #{output.length} data blocks."
puts "Found and decoded #{output_h.keys.length} data blocks."


end # von open ... do |f|

#puts output.to_yaml
#puts output_h.to_yaml
#exit

#f=File.open("#{ARGV[0]}_output.csv", 'w')
#output2=output.map{|x| {'latitude'=>x['latitude'], 'longitude'=>x['longitude'], 'waterDepthM'=>x['waterDepthM']}}
#output2.group_by{|x| [x['latitude'],x['longitude']]}.each do |ll,data|
#  avg_depth = 0
#  data.map{|y| y['waterDepthM']}.each{|summand| avg_depth+=summand}
#  avg_depth = avg_depth / data.length
#  f.puts [ll[0], ll[1], avg_depth].join(';')
#end
#f.puts("Found #{output.length} blocks.")
#f.puts(output.inspect);
#f.puts('--------------- YAML ------------------')
#f.puts(output.to_yaml);
#f.close
rescue Exception => err
	puts err.to_s
	puts err.inspect	
ensure
 	f_raw.close
	puts "Read up to block_offset #{block_offset}"
end
