dofile(scriptPath .. filesystem.preferred("/config.lua"))

local flavour = 'DEFAULT'

if config.flavour then
    flavour = config.flavour
end

local using_split = false

if config.using_split then
    using_split = config.using_split
end

dofile(scriptPath .. filesystem.preferred("/common/monolith.lua"))

monolith.set_flavour(flavour)

local tuning_adjustment=0
if (config.tuning_adjustment) then
    tuning_adjustment=config.tuning_adjustment
end

local files
if (type(config.filepath) == 'table') then
    files = config.filepath
else
    files = {config.filepath}
end

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

function create_zone(groups, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high, file, file_prefix, layer, use_rr)
    local note_name    = monolith.get_note_name(root)
    local sample_start = monolith.get_samples(note_bar_in)
    local sample_end   = monolith.get_samples(note_bar_out)

    print(string.format("Note %3s (%3d) Bar In %4d Bar Out %4d RR %d Bars %d Start %8d End %8d", note_name, root, note_bar_in, note_bar_out, rr, note_duration_bars, sample_start, sample_end))        

    local zone         = Zone()
    zone.rootKey       = root
    zone.volume        = 0
    if (layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN') then
        zone.keyRange.low  = root
    else
        zone.tune = tuning_adjustment / 100
        zone.keyRange.low  = math.max(root - monolith.note_interval + 1, monolith.min_note)
    end
    zone.keyRange.high = root
    zone.velocityRange.low  = vol_low
    zone.velocityRange.high = vol_high

    local group = groups[group_name]
    if using_split then 
        local sample_file = monolith.get_file_name(file_prefix, layer, root, zone.keyRange.low, zone.keyRange.high, vol_low, vol_high, use_rr)
        zone.file = sample_file
    else 
        zone.sampleStart   = sample_start
        zone.sampleEnd     = sample_end
        zone.file = file
    end
    group.zones:add(zone)
end

function setup_layer(groups, file, layer, pedal, group_prefix)
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
    local file_prefix        = string.sub(file, 0, -5)

    if pedal then
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
            create_zone(groups, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high, file, file_prefix, layer, rr)
            note_bar_in = note_bar_in + 6
        end 
    else     
        for i=0,monolith.num_zones-1 do
            local num_rrs            = monolith.get_num_rr(root, layer)
            local note_duration_bars = monolith.get_note_duration_bars(root, layer)
            
            for rr=1,monolith.max_rr do
                local group_name
                if layer == 'RT' then
                    group_name = group_prefix
                else 
                    group_name = group_prefix..' rr'..rr
                end
                
                local use_rr = (rr - 1) % num_rrs
                local note_bar_in  = bar_in + (use_rr * (note_duration_bars + 1))
                local note_bar_out = note_bar_in + note_duration_bars

                create_zone(groups, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high, file, file_prefix, layer, use_rr + 1)
                
                if layer == 'RT' then
                    break
                end
            end

            root   = root + monolith.note_interval
            bar_in = bar_in + ((note_duration_bars + 1) * num_rrs)
        end
    end
end  

function process_samples(start_idx, file)    
    print("Process file ")
    print(file)
    
    local prefix = file:match("([^/]*).wav$")

    local groups = {}
    for i=0,monolith.max_rr-1 do
        local group_name = prefix..' note_without_pedal rr'..(i+1)
        create_group(groups, start_idx + i, group_name)
    end

    for i=monolith.max_rr,(2 * monolith.max_rr)-1 do
        local group_name = prefix..' note_with_pedal rr'..(i-monolith.max_rr+1)
        create_group(groups, start_idx + i, group_name)
    end

    create_group(groups, i, prefix..' release_triggers')

    for i=1,monolith.num_pedal_rr do
        local group_name = prefix..' pedal_down rr'..i
        create_group(groups, start_idx + i, group_name)
    end
    for i=1,monolith.num_pedal_rr do
        local group_name = prefix..' pedal_up rr'..i
        create_group(groups, start_idx + i, group_name)
    end
    
    setup_layer(groups, file, 'F',  false, prefix..' note_without_pedal')
    setup_layer(groups, file, 'F',  true,  prefix..' note_with_pedal')
    setup_layer(groups, file, 'MF', false, prefix..' note_without_pedal')
    setup_layer(groups, file, 'MF', true,  prefix..' note_with_pedal')
    setup_layer(groups, file, 'RT', false, prefix..' release_triggers')
    
    if flavour ~= 'MODULAR' then
        setup_layer(groups, file, 'P',          false, prefix..' note_without_pedal')
        setup_layer(groups, file, 'P',          true,  prefix..' note_with_pedal')
        setup_layer(groups, file, 'PEDAL_DOWN', false, prefix..' pedal_down')
        setup_layer(groups, file, 'PEDAL_UP',   false, prefix..' pedal_up') 
    end  
end

print("Using monolith algorithm "..monolith.flavour)

-- Check for valid instrument.
if not instrument then
    print("The following error message informs you that the Creator Tools are not "..
          "focused on a Kontakt instrument. To solve this, load an instrument in "..
          "Kontakt and select it from the instrument dropdown menu on top.")
else 
    -- Reset the instrument groups.
    instrument.groups:reset()
    for i,sample_file in pairs(files) do       
        local file = scriptPath .. filesystem.preferred("/instruments/" .. sample_file)
        process_samples(i - 1, file)
    end
end
