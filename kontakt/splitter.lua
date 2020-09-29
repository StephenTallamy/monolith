dofile("wav.lua")
dofile("monolith.lua")

local file_path     = "./samples/4006 NR.wav"
monolith.set_flavour("GIMP")

local reader       = wav.create_context(file_path, "r")
local num_channels = reader.get_channels_number()
local sample_rate  = reader.get_sample_rate()
local bitrate      = reader.get_bits_per_sample()

print('------------------------------------------------------------------------------')
print("Filename:    " .. reader.get_filename())
print("Channels:    " .. num_channels)
print("Sample rate: " .. sample_rate)
print("Bitrate:     " .. bitrate)
print('------------------------------------------------------------------------------')

function process_layer(layer, pedal)
    local layer_info  = monolith.get_layer_info(layer)
    local root        = monolith.min_note
    local bar_in      = layer_info['start_bar']
    local vol_low     = layer_info['vol_low']
    local vol_high    = layer_info['vol_high']
    if pedal == true then
        bar_in = layer_info['start_bar_pedal']
    end

    local file_prefix = string.sub(file_path, 0, -5)

    for i=0,monolith.num_zones-1 do
        local note_name          = monolith.get_note_name(root)
        local num_rrs            = monolith.get_num_rr(root, layer)
        local note_duration_bars = monolith.get_note_duration_bars(root, layer)
        
        for rr=1,num_rrs do
            local samples_in  = monolith.get_samples(bar_in)
            local samples_out = monolith.get_samples(bar_in + note_duration_bars)

            reader.set_position(samples_in)

            local samples = reader.get_samples_interlaced(samples_out - samples_in)
            local note_low = math.max(root - monolith.note_interval + 1, monolith.min_note)

            local sample_file = file_prefix.."_r"..root..'_lk'..note_low..'_hk'..root..'_lv'..vol_low..'_hv'..vol_high.."_rr"..rr
            if layer == 'RT' then
               sample_file = sample_file .. "_rt" 
            elseif pedal == true then
               sample_file = sample_file .. "_pedal"
            else 
               sample_file = sample_file .. "_nopedal" 
            end
            sample_file = sample_file..".wav"
            
            print(string.format("Note %3s Start %8d End %8d File %s", note_name, samples_in, samples_out, sample_file))

            local writer = wav.create_context(sample_file, "w")
            writer.init(num_channels, sample_rate, bitrate)
            writer.write_samples_interlaced(samples)
            writer.finish()

            bar_in = bar_in + (note_duration_bars + 1)
        end

        root = root + monolith.note_interval
    end
end

process_layer('F', false)
process_layer('F', true)
process_layer('MF', false)
process_layer('MF', true)
process_layer('P', false)
process_layer('P', true)
process_layer('RT')