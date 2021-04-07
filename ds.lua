dofile("lib/common/filesystem.lua")
dofile("config.lua")
dofile("lib/common/monolith.lua")

monolith.configure(config)

local tuning_adjustment=0
if (config.tuning_adjustment) then
    tuning_adjustment=config.tuning_adjustment
end

local dspresetFile = 'instruments/'..config.instrument..".dspreset"
local file = io.open(dspresetFile, "w")

function write(line)
    file:write(line)
end

function write_line(line)
    file:write(line..'\n')
end

function create_zone(layer, group_name, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high, file_path, file_prefix, pedal, use_rr)
    local note_name    = monolith.get_note_name(root)
    local sample_start = monolith.get_samples(note_bar_in)
    local sample_end   = monolith.get_samples(note_bar_out)
    local note_low     = monolith.get_note_low(root)

    write('      <sample hiNote="' .. root..'" loNote="' .. note_low..'" rootNote="' .. root..'"')
    if monolith.using_split then
        file_path = monolith.get_file_name(file_prefix, layer, root, note_low, root, vol_low, vol_high, use_rr, pedal)
    else
        write(' start="' .. sample_start..'" end="' .. sample_end..'"')
    end
    write_line(' path="'..file_path..'" seqPosition="' .. rr..'" loVel="'..vol_low..'" hiVel="'..vol_high..'"/>')
end

function process_layer(file_path, prefix, layer, pedal)
    local layer_info  = monolith.get_layer_info(layer)
    local root        = monolith.start_note
    local bar_in      = layer_info['start_bar']
    local vol_low     = layer_info['vol_low']
    local vol_high    = layer_info['vol_high']
    if pedal == true then
        bar_in = layer_info['start_bar_pedal']
    end
    
    local group_label
    if layer == 'RT' then
        group_label = prefix..' release_triggers'
        write_line('    <group trigger="release" name="'..group_label..'" volume="'..monolith.rt_boost_db..'dB">')
    elseif (layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN') then
        group_label = prefix..' '..layer:lower()
        local locc64
        local hicc64
        if (layer == 'PEDAL_DOWN') then
            locc64 = 64
            hicc64 = 127
        else
            locc64=0 
            hicc64=63
        end
        write_line('    <group trigger="cc" name="'..group_label..'" onLoCC64="'..locc64..'" onHiCC64="'..hicc64..'" volume="'..monolith.pedal_boost_db..'dB">')
    else
        group_label = prefix..' '..layer
        local locc64
        local hicc64
        if (pedal) then
            locc64 = 64
            hicc64 = 127
            group_label = group_label .. ' notes_with_pedal'
        else
            locc64=0 
            hicc64=63
            group_label = group_label .. ' notes_without_pedal'
        end
        write_line('    <group name="'..group_label..'" loCC64="'..locc64..'" hiCC64="'..hicc64..'">')
    end
    
    local file_prefix = string.sub(file_path, 0, -5)
    if (layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN') then
        local note_bar_in = bar_in
        local note_duration_bars = monolith.get_note_duration_bars(root, layer)
        root = 64 -- matches script
        
        for rr=1,monolith.num_pedal_rr do
            local sample_start = monolith.get_samples(note_bar_in)
            local sample_end   = monolith.get_samples(note_bar_in + note_duration_bars)
            
            write('      <sample pitchKeyTrack="0"')
            if monolith.using_split then
                file_path = monolith.get_file_name(file_prefix, layer, root, root, root, vol_low, vol_high, rr, pedal)
            else
                write(' start="' .. sample_start..'" end="' .. sample_end..'"')
            end
            write_line(' path="'..file_path..'" seqPosition="' .. rr..'"/>')
            
            note_bar_in = note_bar_in + monolith.get_bars_between_pedals()
        end 
    else
        for i=0,monolith.num_zones-1 do
            local num_rrs            = monolith.get_num_rr(root, layer)
            local note_duration_bars = monolith.get_note_duration_bars(root, layer)
            
            for rr=1,monolith.max_rr do  
                local use_rr       = (rr - 1) % num_rrs             
                local note_bar_in  = bar_in + (use_rr * (note_duration_bars + 1))
                local note_bar_out = note_bar_in + note_duration_bars

                create_zone(layer, layer, note_bar_in, note_bar_out, note_duration_bars, root, rr, vol_low, vol_high, file_path, file_prefix, pedal, use_rr + 1)
                
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
local groups = { notes={}, rt={}, pedal={} }
local num_groups_per_file = 9
if monolith.flavour == 'MVP' then
    num_groups_per_file = 5
end
for i,sample_file in pairs(monolith.files) do
    local prefix = monolith.prefix[i]
    process_layer(sample_file, prefix, 'F', false)
    table.insert(groups.notes, (i - 1) * num_groups_per_file + 0)
    process_layer(sample_file, prefix, 'F', true)
    table.insert(groups.notes, (i - 1) * num_groups_per_file + 1)
    process_layer(sample_file, prefix, 'RT')
    table.insert(groups.rt,    (i - 1) * num_groups_per_file + 2)
    process_layer(sample_file, prefix, 'MF', false)
    table.insert(groups.notes, (i - 1) * num_groups_per_file + 3)
    process_layer(sample_file, prefix, 'MF', true)
    table.insert(groups.notes, (i - 1) * num_groups_per_file + 4)
    if monolith.flavour ~= 'MVP' then
        process_layer(sample_file, prefix, 'P', false)
        table.insert(groups.notes, (i - 1) * num_groups_per_file + 5)
        process_layer(sample_file, prefix, 'P', true)
        table.insert(groups.notes, (i - 1) * num_groups_per_file + 6)
        process_layer(sample_file, prefix, 'PEDAL_UP')
        table.insert(groups.pedal, (i - 1) * num_groups_per_file + 7)
        process_layer(sample_file, prefix, 'PEDAL_DOWN')
        table.insert(groups.pedal, (i - 1) * num_groups_per_file + 8)
    end
end

local ui_skin = "background"
if config.ui_skin_ds then
    ui_skin = config.ui_skin_ds
end

write_line('  </groups>')
write_line('  <ui bgImage="Resources/pictures/'..ui_skin..'.png" width="812" height="375" layoutMode="relative" bgMode="top_left">')
write_line('    <tab name="main">')
write_line('      <labeled-knob x="231" y="80" label="NOTES" type="float" minValue="0" maxValue="100" textColor="FFFFFFFF" value="100" textSize="20" width="110" height="130" trackForegroundColor="FFFFFFFF" trackBackgroundColor="FF888888">')
for i,group in pairs(groups.notes) do
    write_line('        <binding type="amp" level="group" position="'..group..'" parameter="AMP_VOLUME" translation="linear" translationOutputMin="0" translationOutputMax="1.0"  />')
end
write_line('      </labeled-knob>')
write_line('      <labeled-knob x="351" y="80" label="RT" type="float" minValue="0" maxValue="100" textColor="FFFFFFFF" value="60" textSize="20" width="110" height="130" trackForegroundColor="FFFFFFFF" trackBackgroundColor="FF888888">')
for i,group in pairs(groups.rt) do
    write_line('        <binding type="amp" level="group" position="'..group..'" parameter="AMP_VOLUME" translation="linear" translationOutputMin="0" translationOutputMax="1.0"  />')
end
write_line('      </labeled-knob>')
write_line('      <labeled-knob x="471" y="80" label="PEDALS" type="float" minValue="0" maxValue="100" textColor="FFFFFFFF" value="60" textSize="20" width="110" height="130" trackForegroundColor="FFFFFFFF" trackBackgroundColor="FF888888">')
for i,group in pairs(groups.pedal) do
    write_line('        <binding type="amp" level="group" position="'..group..'" parameter="AMP_VOLUME" translation="linear" translationOutputMin="0" translationOutputMax="1.0"  />')
end
write_line('      </labeled-knob>')
write_line('    </tab>')
write_line('  </ui>')
write_line('</DecentSampler>')

file:close()

print('Created '..dspresetFile)