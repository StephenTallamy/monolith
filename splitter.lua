dofile("lib/common/filesystem.lua")
dofile("config.lua")

local files
if (type(config.filepath) == 'table') then
    files = config.filepath
else
    files = {config.filepath}
end

dofile("lib/common/wav.lua")
dofile("lib/common/monolith.lua")

monolith.configure(config)

function copy_samples(note_name, bar_in, note_duration_bars, reader, sample_file, num_channels, sample_rate, bitrate)
    local samples_in  = monolith.get_samples(bar_in)
    local samples_out = monolith.get_samples(bar_in + note_duration_bars)

    reader.set_position(samples_in)

    print(string.format("Note %3s Start %8d End %8d File %s", note_name, samples_in, samples_out, sample_file))

    local writer = wav.create_context(sample_file, "w")
    writer.init(num_channels, sample_rate, bitrate)

    local block_align = reader.get_block_align()
    writer.write_raw_bytes(reader.read_raw_bytes((samples_out - samples_in) * block_align))

    writer.finish()
end

function process_layer(reader, layer, pedal, num_channels, sample_rate, bitrate)
    local layer_info  = monolith.get_layer_info(layer)
    local root        = monolith.start_note
    local bar_in      = layer_info['start_bar']
    local vol_low     = layer_info['vol_low']
    local vol_high    = layer_info['vol_high']
    if pedal == true then
        bar_in = layer_info['start_bar_pedal']
    end

    local file_prefix = string.sub(reader.get_filename(), 0, -5)
    if (layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN') then
        local note_duration_bars = 2
        if layer == 'PEDAL_UP' then
            note_duration_bars = 4
        end
        local note_bar_in = bar_in
        root = 64 -- matches script
        
        for rr=1,monolith.num_pedal_rr do
            local sample_file = monolith.get_file_name(file_prefix, layer, root, root, root, vol_low, vol_high, rr, pedal)
            copy_samples(layer, note_bar_in, note_duration_bars, reader, sample_file, num_channels, sample_rate, bitrate)
            note_bar_in = note_bar_in + monolith.get_bars_between_pedals()
        end 
    else 
        for i=0,monolith.num_zones-1 do
            local note_name          = monolith.get_note_name(root)
            local num_rrs            = monolith.get_num_rr(root, layer)
            local note_duration_bars = monolith.get_note_duration_bars(root, layer, pedal)
            
            for rr=1,num_rrs do
                local note_low = monolith.get_note_low(root)

                local sample_file = monolith.get_file_name(file_prefix, layer, root, note_low, root, vol_low, vol_high, rr, pedal)

                copy_samples(note_name, bar_in, note_duration_bars, reader, sample_file, num_channels, sample_rate, bitrate)

                bar_in = bar_in + (note_duration_bars + 1)
            end

            root = root + monolith.note_interval
        end
    end
end

for i,sample_file in pairs(files) do
    local reader       = wav.create_context('instruments/'..sample_file, 'r')
    local num_channels = reader.get_channels_number()
    local sample_rate  = reader.get_sample_rate()
    local bitrate      = reader.get_bits_per_sample()

    print('------------------------------------------------------------------------------')
    print("Filename:    " .. reader.get_filename())
    print("Channels:    " .. num_channels)
    print("Sample rate: " .. sample_rate)
    print("Bitrate:     " .. bitrate)
    print("Flavour:     " .. monolith.flavour)
    print('------------------------------------------------------------------------------')
   
    process_layer(reader, 'F',  true, num_channels, sample_rate, bitrate)
    process_layer(reader, 'RT', false, num_channels, sample_rate, bitrate)
    process_layer(reader, 'MF', true, num_channels, sample_rate, bitrate)
    if monolith.flavour ~= 'MVP' then
        process_layer(reader, 'P',  true, num_channels, sample_rate, bitrate)
        process_layer(reader, 'RT', true, num_channels, sample_rate, bitrate)
        process_layer(reader, 'PEDAL_UP',  false, num_channels, sample_rate, bitrate)
        process_layer(reader, 'PEDAL_DOWN',false, num_channels, sample_rate, bitrate)
    end
    if monolith.flavour ~= 'SAME_PEDALS' and monolith.flavour ~= 'MVP' then
        process_layer(reader, 'F',  false, num_channels, sample_rate, bitrate)
        process_layer(reader, 'MF', false, num_channels, sample_rate, bitrate)
        process_layer(reader, 'P',  false, num_channels, sample_rate, bitrate)
    end
end
