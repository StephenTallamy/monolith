dofile(scriptPath .. filesystem.preferred("/common/monolith.lua"))
monolith.set_flavour('GIMP')

local path     = scriptPath .. filesystem.preferred("/samples/")
local file     = path..'DOES_NOT_EXIST.wav'

function create_group(groups, i, name)
    local group
    if i == 0 then
        group = instrument.groups[0]
    else 
        group = Group()
        instrument.groups:add(group)
    end
    group.name = name
    groups[name] = group
    return group
end

function create_zone(groups, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high)
    local note_name    = monolith.get_note_name(root)
    local sample_start = monolith.get_samples(note_bar_in)
    local sample_end   = monolith.get_samples(note_bar_out)

    print(string.format("Note %3s (%3d) Bar In %4d Bar Out %4d RR %d Bars %d Start %8d End %8d", note_name, root, note_bar_in, note_bar_out, rr, note_duration_bars, sample_start, sample_end))        

    local zone         = Zone()
    zone.rootKey       = root
    zone.volume        = 0
    zone.keyRange.low  = math.max(root - monolith.note_interval + 1, monolith.min_note)
    zone.keyRange.high = root
    zone.sampleStart   = sample_start
    zone.sampleEnd     = sample_end
    zone.velocityRange.low  = vol_low
    zone.velocityRange.high = vol_high

    local group = groups[group_name]
    zone.file = file
    group.zones:add(zone)
end

function setup_layer(groups, file, layer, group_prefix)
    local layer_info         = monolith.get_layer_info(layer)
    if layer_info == nil then
        print('Unknown layer '..layer)
        return 
    end
    local vol_low            = layer_info['vol_low']
    local vol_high           = layer_info['vol_high']
    local start_bar          = layer_info['start_bar']
    local start_bar_pedal    = layer_info['start_bar_pedal']
    local root               = monolith.min_note
    local bar_in             = start_bar

    if group_prefix == 'note_with_pedal' then
        bar_in = start_bar_pedal
    end

    print('------------------------------------------------------------------------------')
    print(string.format("Layer %s Bar In %d Vol Low %d Vol High %d", layer, bar_in, vol_low, vol_high))
    print('------------------------------------------------------------------------------')

    if (layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN') then
        local note_duration_bars = 2
        if layer == 'PEDAL_UP' then
            note_duration_bars = 4
        end
        local note_bar_in = bar_in
        root = 64 -- matches script
        
        for rr=1,monolith.num_pedal_rr do
            local group_name = group_prefix..' rr'..rr
            local note_bar_out = note_bar_in + note_duration_bars
            create_zone(groups, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high)
            note_bar_in = note_bar_in + 6
        end 
    else     
        for i=0,monolith.num_zones-1 do
            local num_rrs            = monolith.get_num_rr(root, layer)
            local note_duration_bars = monolith.get_note_duration_bars(root, layer)
            
            for rr=1,monolith.max_rr do
                local group_name
                if layer == 'RT' then
                    group_name = 'release_triggers'
                else 
                    group_name = group_prefix..' rr'..rr
                end
                
                local note_bar_in  = bar_in + (((rr - 1) % num_rrs) * (note_duration_bars + 1))
                local note_bar_out = note_bar_in + note_duration_bars

                create_zone(groups, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high)
                
                if layer == 'RT' then
                    break
                end
            end

            root   = root + monolith.note_interval
            bar_in = bar_in + ((note_duration_bars + 1) * num_rrs)
        end
    end
end  

function process_samples()

    -- Reset the instrument groups.
    instrument.groups:reset()

    local groups = {}
    for i=0,monolith.max_rr-1 do
        local group_name = 'note_with_pedal rr'..(i+1)
        create_group(groups, i, group_name)
    end

    for i=monolith.max_rr,(2 * monolith.max_rr)-1 do
        local group_name = 'note_without_pedal rr'..(i-monolith.max_rr+1)
        create_group(groups, i, group_name)
    end

    create_group(groups, i, 'release_triggers')

    for i=1,monolith.num_pedal_rr do
        local group_name = 'pedal_down rr'..i
        create_group(groups, i, group_name)
    end
    for i=1,monolith.num_pedal_rr do
        local group_name = 'pedal_up rr'..i
        create_group(groups, i, group_name)
    end
    
    setup_layer(groups, file, 'F' , 'note_without_pedal')
    setup_layer(groups, file, 'RT')
    setup_layer(groups, file, 'MF', 'note_without_pedal')
    if flavour ~= 'MODULAR' then
        setup_layer(groups, file, 'P' , 'note_without_pedal')
    end
    setup_layer(groups, file, 'F' , 'note_with_pedal')
    setup_layer(groups, file, 'MF', 'note_with_pedal')
    if flavour ~= 'MODULAR' then
        setup_layer(groups, file, 'P' , 'note_with_pedal')
        setup_layer(groups, file, 'PEDAL_DOWN' , 'pedal_down')
        setup_layer(groups, file, 'PEDAL_UP' , 'pedal_up') 
    end  
end

print("The samples are located in ")
print(file)
print("Using heatmap algorithm "..monolith.flavour)

-- Check for valid instrument.
if not instrument then
    print("The following error message informs you that the Creator Tools are not "..
          "focused on a Kontakt instrument. To solve this, load an instrument in "..
          "Kontakt and select it from the instrument dropdown menu on top.")
else 
    process_samples()
end
