dofile("wav.lua")
dofile("../common/monolith.lua")

local file_path     = "./samples/DOES_NOT_EXIST.wav"
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

function copy_samples(note_name, bar_in, note_duration_bars, reader, sample_file)
    local samples_in  = monolith.get_samples(bar_in)
    local samples_out = monolith.get_samples(bar_in + note_duration_bars)

    reader.set_position(samples_in)

    local samples = reader.get_samples_interlaced(samples_out - samples_in)
    
    print(string.format("Note %3s Start %8d End %8d File %s", note_name, samples_in, samples_out, sample_file))

    local writer = wav.create_context(sample_file, "w")
    writer.init(num_channels, sample_rate, bitrate)
    writer.write_samples_interlaced(samples)
    writer.finish()
end

function get_file_name(file_prefix, layer, root, note_low, note_high, vol_low, vol_high, rr)
    local sample_file = file_prefix.."_r"..root..'_lk'..note_low..'_hk'..note_high..'_lv'..vol_low..'_hv'..vol_high.."_rr"..rr
    if layer == 'RT' then
        sample_file = sample_file .. "_rt" 
    elseif layer == 'PEDAL_UP' then
        sample_file = sample_file .. "_pedal_up" 
    elseif layer == 'PEDAL_DOWN' then
        sample_file = sample_file .. "_pedal_down"             
    elseif pedal == true then
        sample_file = sample_file .. "_withpedal"
    else 
        sample_file = sample_file .. "_nopedal" 
    end
    sample_file = sample_file..".wav"

    return sample_file
end

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
    if (layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN') then
        local note_duration_bars = 2
        if layer == 'PEDAL_UP' then
            note_duration_bars = 4
        end
        local note_bar_in = bar_in
        root = 64 -- matches script
        
        for rr=1,monolith.num_pedal_rr do
            local sample_file = get_file_name(file_prefix, layer, root, root, root, vol_low, vol_high, rr)
            copy_samples(layer, note_bar_in, note_duration_bars, reader, sample_file)
            note_bar_in = note_bar_in + 6
        end 
    else 
        for i=0,monolith.num_zones-1 do
            local note_name          = monolith.get_note_name(root)
            local num_rrs            = monolith.get_num_rr(root, layer)
            local note_duration_bars = monolith.get_note_duration_bars(root, layer)
            
            for rr=1,num_rrs do
                local note_low = math.max(root - monolith.note_interval + 1, monolith.min_note)

                local sample_file = get_file_name(file_prefix, layer, root, note_low, root, vol_low, vol_high, rr)

                copy_samples(note_name, bar_in, note_duration_bars, reader, sample_file)

                bar_in = bar_in + (note_duration_bars + 1)
            end

            root = root + monolith.note_interval
        end
    end
end

process_layer('F', false)
process_layer('F', true)
process_layer('MF', false)
process_layer('MF', true)
process_layer('P', false)
process_layer('P', true)
process_layer('RT')
process_layer('PEDAL_UP')
process_layer('PEDAL_DOWN')
