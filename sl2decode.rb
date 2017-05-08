require 'yaml'

# Constants:
POLAR_EARTH_RADIUS = 6356752.3142
PI = Math::PI
MAX_UINT4 = 4294967295
FT2M = 1/3.2808399  # factor for feet to meter conversions
KN2KM = 1/1.852     # factor for knots to km conversions

if ARGV[0].to_s==''
  puts "Usage: ruby sl2decode.rb your_file.sl2"
  exit
end

block_offset=0

# 10 Bytes Header
block_offset+=10   # Startindex of the first block (i.e. skip the header)

# Datatypes:
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
output_h = {}
alive_counter = 0   # counter to regularly show, that the script is still running

puts "Hit Ctrl+c to abort. The CSV-File will still contain all records parsed so far."
sleep 3

open ARGV[0], 'r' do |f|
  sl2_file_size = File.size(ARGV[0])
  while block_offset<sl2_file_size do
    h={}
    alive_counter += 1
    if alive_counter % 100 == 0
      puts "#{(100.0*block_offset/sl2_file_size).round}% done..."
    end

    block_def.each do |key,bdef|
      f.seek(block_offset+bdef[:offset])
      h[key] = f.read(bdef[:len]).unpack(bdef[:type]).first
    end


    # A few conversions into non-proprietary or metric formats:
    # =========================================================

    h['longitude'] = h['lowrance_longitude']/POLAR_EARTH_RADIUS * (180/PI) if h.has_key?('lowrance_longitude')
    # [ Caution! ] If the expected longitude (in decimal degrees) is *negative*, use the following line instead:
    # h['longitude'] = (h['lowrance_longitude'] - MAX_UINT4) / POLAR_EARTH_RADIUS * (180/PI) if h.has_key?('lowrance_longitude')

    h['latitude'] = ((2*Math.atan(Math.exp(h['lowrance_latitude']/POLAR_EARTH_RADIUS)))-(PI/2)) * (180/PI) if h.has_key?('lowrance_latitude')

    h['waterDepthM'] = h['waterDepthFt'] * FT2M if h.has_key?('waterDepthFt')

    h['keelDepthM']  = h['keelDepthFt'] * FT2M if h.has_key?('keelDepthFt')

    h['altitudeM']   = h['altitudeFt'] * FT2M if h.has_key?('altitudeFt')

    h['speedGpsKm']  = h['speedGpsKnots'] * KN2KM if h.has_key?('speedGpsKnots')



    begin
      if h['blockSize']==0   # corrupt sl2 files may lead to this
        puts "ABORTING, blockSize=0 found, which will otherwise lead to endless loop."
        exit
      end
      block_offset += h['blockSize']
    rescue
      raise h.inspect
    end

    # Save only one set of data per GPS position to csv-file:
    unless output_h[[h['latitude'], h['longitude']]]
      output_h[[h['latitude'], h['longitude']]] = h['waterDepthM']

      # Here we prepare one line that will be written into the csv-file. Adjust to your personal needs:
      csv_line = [h['longitude'], h['latitude'], h['waterDepthM']].join(' ')+';'

      # Finally the prepared line is written to the csv-file:
      f_raw.puts(csv_line)
    end
  end

  # When finished, output some statistics:
  puts "Found and decoded #{output_h.keys.length} data blocks (distinct gps positions)."


end # of "open ... do |f|"

rescue Exception => err
	puts err.to_s
	puts err.inspect	
ensure  # even on ctrl+c ensure that the csv-file is finally closed:
 	f_raw.close
	puts "Read up to block_offset #{block_offset}"
end

