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

local file = io.open('instruments/'..config.instrument..".sfz", "w")

function write_line(line)
    file:write(line..'\n')
end    

function create_zone(layer, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, use_rr, vol_low, vol_high, file_prefix, pedal)
    local note_name    = monolith.get_note_name(root)
    local note_low     = math.max(root - monolith.note_interval + 1, monolith.min_note)
    
    write_line(string.format("// Note %s Group %s RR %d Bar In %d Bar Out %d", note_name, group_name, rr, note_bar_in, note_bar_out)) 
    write_line('<region>')
    if using_split then 
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
        write_line('<group>')
        write_line('group_label=Layer '..layer)
        if using_split == false then
            write_line('sample=' .. file_path)
        end
        write_line('hikey=0')
        write_line('lokey=0')
        write_line('volume='..pedal_volume)
        local note_duration_bars = 2
        if layer == 'PEDAL_UP' then
            note_duration_bars = 4
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
            if using_split then 
                local sample_file = monolith.get_file_name(file_prefix, layer, 64, 64, 64, vol_low, vol_high, rr, pedal)
                write_line('sample='..sample_file)
            else
                write_line('offset=' .. sample_start)
                write_line('end=' .. sample_end)
            end
            write_line('seq_position=' .. rr)
            write_line('')
            
            note_bar_in = note_bar_in + 6
        end 
    else 
        write_line('<group>')
        local group_label
        if using_split == false then
            write_line('sample=' .. file_path)
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
            group_label = 'Release Triggers'
        else
            write_line('volume='..note_volume)
            write_line('xfin_locc23=0')
            write_line('xfin_hicc23=127')
            write_line('seq_length='..monolith.max_rr)
            group_label = 'Layer '..layer
            if (pedal) then
                group_label = group_label .. ' (with pedal)'
                write_line('locc64=64') 
                write_line('hicc64=127')
            else
                group_label = group_label .. ' (without pedal)'
                write_line('locc64=0') 
                write_line('hicc64=63')
            end
        end
        write_line('group_label='..group_label)
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

process_layer('F', false)
process_layer('F', true)
process_layer('MF', false)
process_layer('MF', true)
process_layer('P', false)
process_layer('P', true)
process_layer('RT')
process_layer('PEDAL_UP')
process_layer('PEDAL_DOWN')

file:close()