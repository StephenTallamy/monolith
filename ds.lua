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

    print(string.format("Note %3s (%3d) Bar In %4d Bar Out %4d RR %d Bars %d Start %8d End %8d", note_name, root, note_bar_in, note_bar_out, rr, note_duration_bars, sample_start, sample_end))

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
    if layer_info == nil then
        return false
    end
    local root        = monolith.start_note
    local bar_in      = layer_info['start_bar']
    local vol_low     = layer_info['vol_low']
    local vol_high    = layer_info['vol_high']
    if pedal == true then
        bar_in = layer_info['start_bar_pedal']
    end

    print('------------------------------------------------------------------------------')
    print(string.format("Layer %s Group Prefix %s Bar In %d Vol Low %d Vol High %d", layer, prefix, bar_in, vol_low, vol_high))
    print('------------------------------------------------------------------------------')

    local group_tags = 'MIC_'..prefix
    local group_label
    if layer == 'RT' then
        group_label = prefix..' release_triggers'
        group_tags = group_tags..',RT'
        write_line('    <group trigger="release" name="'..group_label..'" volume="'..monolith.rt_boost_db..'dB" tags="'..group_tags..'">')
    elseif (layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN') then
        group_label = prefix..' '..layer:lower()
        group_tags = group_tags..',PEDALS'
        local locc64
        local hicc64
        if (layer == 'PEDAL_DOWN') then
            locc64 = 64
            hicc64 = 127
        else
            locc64=0 
            hicc64=63
        end
        write_line('    <group trigger="cc" name="'..group_label..'" onLoCC64="'..locc64..'" onHiCC64="'..hicc64..'" volume="'..monolith.pedal_boost_db..'dB" tags="'..group_tags..'">')
    else
        group_label = prefix..' '..layer
        group_tags = group_tags..',NOTES'
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
        write_line('    <group name="'..group_label..'" loCC64="'..locc64..'" hiCC64="'..hicc64..'" tags="'..group_tags..'" attack="'..monolith.adsr.attack..'" decay="'..monolith.adsr.decay..'" sustain="'..monolith.adsr.sustain..'" release="'..monolith.adsr.release..'">')
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
    return true
end

write_line('<?xml version="1.0" encoding="UTF-8"?>')
write_line('<DecentSampler pluginVersion="1">')
write_line('  <groups>')
local groups = { notes={}, rt={}, pedal={} }
local num_groups_per_file = 9
local num_mics = #monolith.files
if monolith.flavour == 'MVP' then
    num_groups_per_file = 5
end
for i,sample_file in pairs(monolith.files) do
    local prefix = monolith.prefix[i]
    local offset = 0
    if process_layer(sample_file, prefix, 'F', false) then
        table.insert(groups.notes, (i - 1) * num_groups_per_file + offset)
        offset = offset + 1
    end
    if process_layer(sample_file, prefix, 'F', true) then
        table.insert(groups.notes, (i - 1) * num_groups_per_file + offset)
        offset = offset + 1
    end
    if process_layer(sample_file, prefix, 'RT') then
        table.insert(groups.rt,    (i - 1) * num_groups_per_file + offset)
        offset = offset + 1
    end
    if process_layer(sample_file, prefix, 'MF', false) then
        table.insert(groups.notes, (i - 1) * num_groups_per_file + offset)
        offset = offset + 1
    end
    if process_layer(sample_file, prefix, 'MF', true) then
        table.insert(groups.notes, (i - 1) * num_groups_per_file + offset)
        offset = offset + 1
    end
    if process_layer(sample_file, prefix, 'P', false) then
        table.insert(groups.notes, (i - 1) * num_groups_per_file + offset)
        offset = offset + 1
    end
    if process_layer(sample_file, prefix, 'P', true) then
        table.insert(groups.notes, (i - 1) * num_groups_per_file + offset)
        offset = offset + 1
    end
    if process_layer(sample_file, prefix, 'PEDAL_UP') then
        table.insert(groups.pedal, (i - 1) * num_groups_per_file + offset)
        offset = offset + 1
    end
    if process_layer(sample_file, prefix, 'PEDAL_DOWN') then
        table.insert(groups.pedal, (i - 1) * num_groups_per_file + offset)
        offset = offset + 1
    end
end

local ui_skin = "background"
if config.ui_skin_ds then
    ui_skin = config.ui_skin_ds
end

write_line('  </groups>')
write_line('  <ui bgImage="Resources/pictures/'..ui_skin..'.png" width="812" height="375" layoutMode="relative" bgMode="top_left">')
write_line('    <tab name="main">')
write_line('      <labeled-knob x="271" y="80" label="NOTES" type="float" minValue="0" maxValue="100" textColor="FFFFFFFF" value="100" textSize="20" width="110" height="130" trackForegroundColor="FFFFFFFF" trackBackgroundColor="FF888888">')
for i,group in pairs(groups.notes) do
    write_line('        <binding type="amp" level="group" position="'..group..'" parameter="AMP_VOLUME" translation="linear" translationOutputMin="0" translationOutputMax="1.0"  />')
end
write_line('      </labeled-knob>')

if monolith.get_layer_info('RT') ~= nil then
    write_line('      <labeled-knob x="371" y="80" label="RT" type="float" minValue="0" maxValue="100" textColor="FFFFFFFF" value="60" textSize="20" width="110" height="130" trackForegroundColor="FFFFFFFF" trackBackgroundColor="FF888888">')
    for i,group in pairs(groups.rt) do
        write_line('        <binding type="amp" level="group" position="'..group..'" parameter="AMP_VOLUME" translation="linear" translationOutputMin="0" translationOutputMax="1.0"  />')
    end
    write_line('      </labeled-knob>')
end
if monolith.get_layer_info('PEDAL_DOWN') ~= nil then
    write_line('      <labeled-knob x="471" y="80" label="PEDALS" type="float" minValue="0" maxValue="100" textColor="FFFFFFFF" value="60" textSize="20" width="110" height="130" trackForegroundColor="FFFFFFFF" trackBackgroundColor="FF888888">')
    for i,group in pairs(groups.pedal) do
        write_line('        <binding type="amp" level="group" position="'..group..'" parameter="AMP_VOLUME" translation="linear" translationOutputMin="0" translationOutputMax="1.0"  />')
    end
    write_line('      </labeled-knob>')
end
write_line('      <labeled-knob x="571" y="80" label="FX1" type="percent" minValue="0" maxValue="100" textColor="FFFFFFFF" value="0" textSize="20" width="110" height="130" trackForegroundColor="FFFFFFFF" trackBackgroundColor="FF888888">')
write_line('        <binding type="effect" level="instrument" position="0" parameter="FX_REVERB_WET_LEVEL" factor="0.01"/>')
write_line('      </labeled-knob>')
write_line('      <labeled-knob x="671" y="80" label="FX2" type="percent" minValue="0" maxValue="100" textColor="FFFFFFFF" value="70" textSize="20" width="110" height="130" trackForegroundColor="FFFFFFFF" trackBackgroundColor="FF888888">')
write_line('        <binding type="effect" level="instrument" position="0" parameter="FX_REVERB_ROOM_SIZE" factor="0.01"/>')
write_line('      </labeled-knob>')
if num_mics > 1 then
    local x_pos = 40
    if num_mics > 3 then
        x_pos = 0  
    end

    for i,prefix in pairs(monolith.prefix) do
        x_pos = x_pos + 60
        write_line('      <label x="'..(x_pos - 45)..'" y="80" width="110" height="30" text="'..prefix:upper()..'" textColor="FFFFFFFF" textSize="15" />')
        write_line('      <control x="'..x_pos..'" y="115" parameterName="'..prefix..'" style="linear_bar_vertical" type="float" minValue="0" maxValue="100" value="60" width="20" height="70" trackForegroundColor="FFFFFFFF" trackBackgroundColor="FF888888">')
        write_line('        <binding type="amp" level="tag" identifier="MIC_'..prefix..'" parameter="AMP_VOLUME" translation="linear" translationOutputMin="0" translationOutputMax="1.0" />')
        write_line('      </control>')
    end
end
write_line('    </tab>')
write_line('  </ui>')
write_line('  <effects>')
write_line('    <effect type="reverb" wetLevel="0" roomSize="0.7"/>')
write_line('  </effects>')
write_line('</DecentSampler>')

file:close()

print('Created '..dspresetFile)