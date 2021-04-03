dofile("config.lua")
dofile("lib/common/monolith.lua")

monolith.configure(config)

local note_volume=15
local rt_volume=15
local pedal_volume=5
local tuning_adjustment=0

if (config.tuning_adjustment) then
    tuning_adjustment=config.tuning_adjustment
end

local file = io.open('instruments/'..config.instrument..".sfz", "w")

function write_line(line)
    file:write(line..'\n')
end    

function create_zone(layer, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, use_rr, vol_low, vol_high, file_prefix, pedal)
    local note_name    = monolith.get_note_name(root)
    local note_low     = math.max(root - monolith.note_interval + 1, monolith.min_note)
    
    write_line(string.format("// Note %s Group %s RR %d Bar In %d Bar Out %d", note_name, group_name, rr, note_bar_in, note_bar_out)) 
    write_line('<region>')
    if monolith.using_split then 
        local sample_file = monolith.get_file_name(file_prefix, layer, root, note_low, root, vol_low, vol_high, use_rr, pedal)
        write_line('sample='..sample_file)
    else
        local sample_start = monolith.get_samples(note_bar_in)
        local sample_end   = monolith.get_samples(note_bar_out)
        write_line('offset=' .. sample_start)
        write_line('end=' .. sample_end)
    end
    write_line('hikey=' .. root)
    write_line('lokey=' .. note_low)
    write_line('pitch_keycenter=' .. root) 
    write_line('seq_position=' .. rr)
    write_line('')
end

function process_layer(sample_file, prefix, layer, pedal)
    local layer_info  = monolith.get_layer_info(layer)
    local root        = monolith.min_note
    local bar_in      = layer_info['start_bar']
    local vol_low     = layer_info['vol_low']
    local vol_high    = layer_info['vol_high']
    if pedal == true then
        bar_in = layer_info['start_bar_pedal']
    end

    local file_prefix = string.sub(sample_file, 0, -5)
    if (layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN') then
        write_line('<group>')
        write_line('group_label='..prefix..' '..layer:lower())
        if monolith.using_split == false then
            write_line('sample=' .. sample_file)
        end
        write_line('hikey=0')
        write_line('lokey=0')
        write_line('volume='..pedal_volume)
        local note_duration_bars = monolith.get_note_duration_bars(root, layer)
        if layer == 'PEDAL_UP' then
            write_line('start_locc64=0')
            write_line('start_hicc64=63')
        else
            write_line('start_locc64=64')
            write_line('start_hicc64=127')
        end
        write_line('seq_length='..monolith.num_pedal_rr)
        write_line('xfin_locc25=0')
        write_line('xfin_hicc25=127')
        write_line('')

        local note_bar_in = bar_in

        for rr=1,monolith.num_pedal_rr do
            local sample_start = monolith.get_samples(note_bar_in)
            local sample_end   = monolith.get_samples(note_bar_in+note_duration_bars)
            write_line('<region>')
            if monolith.using_split then 
                local sample_file = monolith.get_file_name(file_prefix, layer, 64, 64, 64, vol_low, vol_high, rr, pedal)
                write_line('sample='..sample_file)
            else
                write_line('offset=' .. sample_start)
                write_line('end=' .. sample_end)
            end
            write_line('seq_position=' .. rr)
            write_line('')
            
            note_bar_in = note_bar_in + monolith.get_bars_between_pedals()
        end 
    else 
        write_line('<group>')
        local group_label
        if monolith.using_split == false then
            write_line('sample=' .. sample_file)
        end
        write_line('lovel='..vol_low)
        write_line('hivel='..vol_high)
        write_line('tune='..tuning_adjustment)
        if layer == 'RT' then
            write_line('volume='..rt_volume)
            write_line('trigger=release_key')
            write_line('seq_length=1')
            write_line('xfin_locc24=0')
            write_line('xfin_hicc24=127')
            write_line('loop_mode=one_shot')
            write_line('rt_decay=6')
            group_label = 'release_triggers'
        else
            write_line('volume='..note_volume)
            write_line('xfin_locc23=0')
            write_line('xfin_hicc23=127')
            write_line('seq_length='..monolith.max_rr)
            group_label = layer
            if (pedal) then
                group_label = group_label .. ' note_with_pedal'
                write_line('locc64=64') 
                write_line('hicc64=127')
            else
                group_label = group_label .. ' note_without_pedal'
                write_line('locc64=0') 
                write_line('hicc64=63')
            end
        end
        write_line('group_label='..prefix..' '..group_label)
        write_line('')

        for i=0,monolith.num_zones-1 do
            local num_rrs            = monolith.get_num_rr(root, layer)
            local note_duration_bars = monolith.get_note_duration_bars(root, layer)
            
            for rr=1,monolith.max_rr do   
                local use_rr       = (rr - 1) % num_rrs             
                local note_bar_in  = bar_in + (use_rr * (note_duration_bars + 1))
                local note_bar_out = note_bar_in + note_duration_bars

                create_zone(layer, layer, note_bar_in, note_bar_out, note_duration_bars, root, rr, use_rr + 1, vol_low, vol_high, file_prefix, pedal)
                
                if layer == 'RT' then
                    break
                end
            end

            root   = root + monolith.note_interval
            bar_in = bar_in + ((note_duration_bars + 1) * num_rrs)
        end
    end
end

write_line('<control>')
write_line('label_cc007=Volume')
write_line('label_cc0010=Pan')
write_line('label_cc023=Notes Volume')
write_line('label_cc024=RT Volume')
write_line('label_cc025=Pedal Volume')
write_line('label_cc064=Sustain Pedal')
write_line('set_cc007=127')
write_line('set_cc010=64')
write_line('set_cc023=127')
write_line('set_cc024=127')
write_line('set_cc025=127')
write_line('')

write_line('<global>')
write_line('ampeg_attack=0.005')
write_line('ampeg_decay=0')
write_line('ampeg_sustain=100')
write_line('ampeg_release=0.6')
write_line('ampeg_hold=0')
write_line('ampeg_delay=0')
write_line('')

for i,sample_file in pairs(monolith.files) do
    local prefix = monolith.prefix[i]
    process_layer(sample_file, prefix, 'F', false)
    process_layer(sample_file, prefix, 'F', true)
    process_layer(sample_file, prefix, 'MF', false)
    process_layer(sample_file, prefix, 'MF', true)
    process_layer(sample_file, prefix, 'P', false)
    process_layer(sample_file, prefix, 'P', true)
    process_layer(sample_file, prefix, 'RT')
    process_layer(sample_file, prefix, 'PEDAL_UP')
    process_layer(sample_file, prefix, 'PEDAL_DOWN')
end
file:close()