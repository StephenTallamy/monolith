dofile("config.lua")

local file_path = config.filepath

local flavour = 'DEFAULT'

if config.flavour then
    flavour = config.flavour
end

local using_split = false

if config.using_split then
    using_split = config.using_split
end

dofile("common/monolith.lua")

monolith.set_flavour(flavour)

local note_volume=20
local rt_volume=25
local pedal_volume=5
local tuning_adjustment=0

if (monolith.flavour == 'GIMP') then
    tuning_adjustment=30
end

local file = io.open('instruments/'..config.instrument..".dspreset", "w")

function write(line)
    file:write(line)
end

function write_line(line)
    file:write(line..'\n')
end

function create_zone(group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high, file_path, file_prefix, pedal, use_rr)
    local note_name    = monolith.get_note_name(root)
    local sample_start = monolith.get_samples(note_bar_in)
    local sample_end   = monolith.get_samples(note_bar_out)
    local note_low     = math.max(root - monolith.note_interval + 1, monolith.min_note)

    write('      <sample hiNote="' .. root..'" loNote="' .. note_low..'" rootNote="' .. root..'"')
    if using_split then
        file_path = monolith.get_file_name(file_prefix, layer, root, note_low, root, vol_low, vol_high, use_rr, pedal)
    else
        write(' start="' .. sample_start..'" end="' .. sample_end..'"')
    end
    write_line(' path="'..file_path..'" seqPosition="' .. rr..'" loVel="'..vol_low..'" hiVel="'..vol_high..'"/>')
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
    
    
    local group_label
    if layer == 'RT' then
        group_label = 'Release Triggers'
        write_line('    <group trigger="release" name="'..group_label..'">')
    else
        group_label = 'Layer '..layer
        local locc64
        local hicc64
        if (pedal) then
            locc64 = 64
            hicc64 = 127
            group_label = group_label .. ' (with pedal)'
        else
            locc64=0 
            hicc64=63
            group_label = group_label .. ' (without pedal)'
        end
        write_line('    <group name="'..group_label..'" loCC64="'..locc64..'" hiCC64="'..hicc64..'">')
    end
    
    local file_prefix = string.sub(file_path, 0, -5)
    if (layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN') then
        local note_bar_in = bar_in

        for rr=1,monolith.num_pedal_rr do
            local sample_start = monolith.get_samples(note_bar_in)
            local sample_end   = monolith.get_samples(note_bar_in+note_duration_bars)
            
            -- TODO
            
            note_bar_in = note_bar_in + 6
        end 
    else
        for i=0,monolith.num_zones-1 do
            local num_rrs            = monolith.get_num_rr(root, layer)
            local note_duration_bars = monolith.get_note_duration_bars(root, layer)
            
            for rr=1,monolith.max_rr do  
                local use_rr       = (rr - 1) % num_rrs             
                local note_bar_in  = bar_in + (use_rr * (note_duration_bars + 1))
                local note_bar_out = note_bar_in + note_duration_bars

                create_zone(layer, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high, file_path, file_prefix, pedal, use_rr + 1)
                
                if layer == 'RT' then
                    break
                end
            end

            root   = root + monolith.note_interval
            bar_in = bar_in + ((note_duration_bars + 1) * num_rrs)
        end      
    end
    write_line('    </group>')
end

write_line('<?xml version="1.0" encoding="UTF-8"?>')
write_line('<DecentSampler pluginVersion="1">')
write_line('  <groups>')

process_layer('F', false)
process_layer('F', true)
process_layer('MF', false)
process_layer('MF', true)
process_layer('P', false)
process_layer('P', true)
process_layer('RT')
-- process_layer('PEDAL_UP')
-- process_layer('PEDAL_DOWN')

write_line('  </groups>')
write_line('</DecentSampler>')

file:close()