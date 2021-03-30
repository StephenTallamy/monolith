dofile(scriptPath .. filesystem.preferred("/config.lua"))
dofile(scriptPath .. filesystem.preferred("/common/monolith.lua"))

monolith.configure(config)

local tuning_adjustment=0
if (config.tuning_adjustment) then
    tuning_adjustment=config.tuning_adjustment
end

function create_group(groups, name, clone)
    if clone then
        instrument.groups:add(instrument.groups[0])
    else
        instrument.groups:add(Group())
    end
    local group = instrument.groups[#instrument.groups - 1]
    group.name = name
    groups[name] = group
    return group
end

function create_zone(groups, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high, file, file_prefix, layer, use_rr, pedal)
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
    if monolith.using_split then 
        local sample_file = monolith.get_file_name(file_prefix, layer, root, zone.keyRange.low, zone.keyRange.high, vol_low, vol_high, use_rr, pedal)
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
    print(string.format("Layer %s Group Prefix %s Bar In %d Vol Low %d Vol High %d", layer, group_prefix, bar_in, vol_low, vol_high))
    print('------------------------------------------------------------------------------')

    if (layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN') then
        local note_duration_bars = monolith.get_note_duration_bars(root, layer)
        local note_bar_in = bar_in
        root = 64 -- matches script
        
        for rr=1,monolith.num_pedal_rr do
            local group_name = group_prefix..' rr'..rr
            local note_bar_out = note_bar_in + note_duration_bars
            create_zone(groups, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high, file, file_prefix, layer, rr, pedal)
            note_bar_in = note_bar_in + monolith.get_bars_between_pedals()
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

                create_zone(groups, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high, file, file_prefix, layer, use_rr + 1, pedal)
                
                if layer == 'RT' then
                    break
                end
            end

            root   = root + monolith.note_interval
            bar_in = bar_in + ((note_duration_bars + 1) * num_rrs)
        end
    end
end  

function process_samples(file, prefix)    
    print("Process file ")
    print(file)

    local groups = {}
    for i=0,monolith.max_rr-1 do
        local group_name = prefix..' note_without_pedal rr'..(i+1)
        create_group(groups, group_name, true)
    end

    for i=monolith.max_rr,(2 * monolith.max_rr)-1 do
        local group_name = prefix..' note_with_pedal rr'..(i-monolith.max_rr+1)
        create_group(groups, group_name, true)
    end

    create_group(groups, prefix..' release_triggers', false)

    for i=1,monolith.num_pedal_rr do
        local group_name = prefix..' pedal_down rr'..i
        create_group(groups, group_name, false)
    end
    for i=1,monolith.num_pedal_rr do
        local group_name = prefix..' pedal_up rr'..i
        create_group(groups, group_name, false)
    end
    
    setup_layer(groups, file, 'F',  true,  prefix..' note_with_pedal')
    setup_layer(groups, file, 'MF', true,  prefix..' note_with_pedal')
    setup_layer(groups, file, 'P',  true,  prefix..' note_with_pedal')
    setup_layer(groups, file, 'RT', false, prefix..' release_triggers')

    setup_layer(groups, file, 'F',  false, prefix..' note_without_pedal')
    setup_layer(groups, file, 'MF', false, prefix..' note_without_pedal')
    setup_layer(groups, file, 'P',  false, prefix..' note_without_pedal')
    
    setup_layer(groups, file, 'PEDAL_DOWN', false, prefix..' pedal_down')
    setup_layer(groups, file, 'PEDAL_UP',   false, prefix..' pedal_up') 
end

print("Using monolith algorithm "..monolith.flavour)

-- Check for valid instrument.
if not instrument then
    print("The following error message informs you that the Creator Tools are not "..
          "focused on a Kontakt instrument. To solve this, load an instrument in "..
          "Kontakt and select it from the instrument dropdown menu on top.")
else 
    -- Set the name
    instrument.name = config.instrument
    -- Reset the instrument groups.
    instrument.groups:resize(1)
    instrument.groups[0].name = "Default group_template"
    instrument.groups[0].zones:reset()
    for i,sample_file in pairs(monolith.files) do
        local prefix = monolith.prefix[i]     
        local file = scriptPath .. filesystem.preferred("/instruments/" .. sample_file)
        process_samples(file, prefix)
    end

    note_groups = {}
    release_trigger_groups = {}
    pedal_groups = {}
    note_without_pedal_groups = {}
    note_with_pedal_groups = {}
    pedal_down_groups = {}
    pedal_up_groups = {}
    for n=0,#instrument.groups-1 do
        local group_name = instrument.groups[n].name
        if string.match(group_name, "note_") then
            table.insert(note_groups, n)
            if (string.match(group_name, "without")) then
                table.insert(note_without_pedal_groups, n)
            else
                table.insert(note_with_pedal_groups, n)
            end
        elseif string.match(group_name, "pedal_") then
            table.insert(pedal_groups, n)
            if (string.match(group_name, "down")) then
                table.insert(pedal_down_groups, n)
            else
                table.insert(pedal_up_groups, n)
            end
        elseif string.match(group_name, "release_triggers") then
            table.insert(release_trigger_groups, n)    
        end
    end
    num_mics = #monolith.files

    -- Total groups per mic are two lots of note rr (pedal/no-pedal), two lots of pedal rr plus one lot of release triggers
    num_groups_per_mic = (monolith.max_rr * 2) + (monolith.num_pedal_rr * 2) + 1

    if num_mics > 1 then
        dofile(scriptPath .. filesystem.preferred("/kontakt/Pianobook Piano Template - UI (with Mic Levels).lua"))
        dofile(scriptPath .. filesystem.preferred("/kontakt/Pianobook Piano Template - Voice Triggering (with Mic Levels).lua"))
    else
        dofile(scriptPath .. filesystem.preferred("/kontakt/Pianobook Piano Template - UI.lua"))
        dofile(scriptPath .. filesystem.preferred("/kontakt/Pianobook Piano Template - Voice Triggering.lua"))
    end

    instrument.scripts[0].name = "Pianobook UI"
    instrument.scripts[0].sourceCode = ui_script
    instrument.scripts[1].name = "Note Triggering"
    instrument.scripts[1].sourceCode = trigger_script
end
