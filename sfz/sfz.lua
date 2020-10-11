dofile("../common/monolith.lua")

local file_path     = "./samples/DOES_NOT_EXIST.wav"
monolith.set_flavour("GIMP")

function create_zone(group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high)
    local note_name    = monolith.get_note_name(root)
    local sample_start = monolith.get_samples(note_bar_in)
    local sample_end   = monolith.get_samples(note_bar_out)
    local note_low     = math.max(root - monolith.note_interval + 1, monolith.min_note)

    print(string.format("// Note %s Group %s RR %d Bar In %d Bar Out %d", note_name, group_name, rr, note_bar_in, note_bar_out)) 
    print('<region>')
    print('sample=' .. file_path)
    print('hikey=' .. root)
    print('lokey=' .. note_low)
    print('pitch_keycenter=' .. root)
    print('offset=' .. sample_start)
    print('end=' .. sample_end)
    print('seq_position=' .. rr)
    print('')
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
            
            
            note_bar_in = note_bar_in + 6
        end 
    else 
        print('<group>')
        print('group_label=Layer '..layer)
        print('lovel='..vol_low)
        print('hivel='..vol_high)
        if layer == 'RT' then
            print('trigger=release_key')
            print('seq_length=1')
            print('xfin_locc24=0')
            print('xfin_hicc24=127')
            print('loop_mode=one_shot')
            print('rt_decay=6')
        else
            print('xfin_locc23=0')
            print('xfin_hicc23=127')
            print('seq_length='..monolith.max_rr)
            if (pedal) then
                print('locc64=64') 
                print('hicc64=127')
            else
                print('locc64=0') 
                print('hicc64=63')
            end
        end
        print('')

        for i=0,monolith.num_zones-1 do
            local num_rrs            = monolith.get_num_rr(root, layer)
            local note_duration_bars = monolith.get_note_duration_bars(root, layer)
            
            for rr=1,monolith.max_rr do                
                local note_bar_in  = bar_in + (((rr - 1) % num_rrs) * (note_duration_bars + 1))
                local note_bar_out = note_bar_in + note_duration_bars

                create_zone(layer, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high)
                
                if layer == 'RT' then
                    break
                end
            end

            root   = root + monolith.note_interval
            bar_in = bar_in + ((note_duration_bars + 1) * num_rrs)
        end
    end
end

print('<control>')
print('label_cc007=Volume')
print('label_cc023=Notes Volume')
print('label_cc024=RT Volume')
print('set_cc023=127')
print('set_cc024=127')
print('')

process_layer('F', false)
process_layer('F', true)
process_layer('MF', false)
process_layer('MF', true)
process_layer('P', false)
process_layer('P', true)
process_layer('RT')
--process_layer('PEDAL_UP')
--process_layer('PEDAL_DOWN')