local path = scriptPath .. filesystem.preferred("/Summer Piano Samples/")

local num_zones       = 30
local note_interval   = 3
local min_note        = 21
local sample_rate     = 48000
local time_signature  = 4
local bpm             = 115.2
local max_rr          = 3

local layer_map = { 
    F = {
        vol_low            = 120,
        vol_high           = 127,
        note_duration_bars = 7,
        start_bar          = 1
    }, 
    MF = {
        vol_low            = 96, 
        vol_high           = 119,
        note_duration_bars = 7,
        start_bar          = 1
    }, 
    P = {
        vol_low            = 1, 
        vol_high           = 95,
        note_duration_bars = 7,
        start_bar          = 1
    },
    RT = {
        vol_low            = 1, 
        vol_high           = 127,
        note_duration_bars = 3,
        start_bar          = 1
    }
}

local note_map = {"C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"}

function get_note_name(note_num)
   local idx = (note_num % 12) + 1
   local octave = math.floor(note_num / 12) - 2
   return note_map[idx]..octave
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

function setup_group(group, file, layer_info)
    print('Adding '..file..' to group '..group.name) 
    local vol_low            = layer_info['vol_low']
    local vol_high           = layer_info['vol_high']
    local note_duration_bars = layer_info['note_duration_bars']
    local start_bar          = layer_info['start_bar']
    local root               = 21
    local note_bar_in        = start_bar
    for i=0,num_zones-1 do
        local note_name    = get_note_name(root)
        local zone         = Zone()
        local note_bar_out = note_bar_in + note_duration_bars
        local sample_start = math.floor((60 / bpm) * (note_bar_in - 1) * time_signature * sample_rate)
        local sample_end   = math.floor((60 / bpm) * (note_bar_in + note_duration_bars - 2) * time_signature * sample_rate)
        print(string.format("Note %3s (%3d) Bar In %4d Bar Out %4d Bars %d Start %8d End %8d", note_name, root, note_bar_in, note_bar_out, note_duration_bars, sample_start, sample_end))       
        
        -- Set the zone root key, high range and low range to the same values thus confining the zone to a single note.
        zone.rootKey       = root
        zone.keyRange.low  = math.max(root - note_interval + 1, min_note)
        zone.keyRange.high = root
        zone.sampleStart   = sample_start
        zone.sampleEnd     = sample_end
        zone.velocityRange.low  = vol_low
        zone.velocityRange.high = vol_high

        zone.file = path..file
        group.zones:add(zone)

        root = root + note_interval
        note_bar_in = note_bar_in + note_duration_bars
    end
end  

function process_samples()

    -- Declare an empty table which we will fill with the samples.
    local samples = {}

    for _,p in filesystem.directoryRecursive(path) do
        if filesystem.isRegularFile(p) then
            if filesystem.extension(p) == '.wav' or filesystem.extension(p) == '.aif' or filesystem.extension(p) == '.aiff' then
                local filename = filesystem.filename(p)
                local file_no_ext = filename:match("(.+)%..+")
                local i = 0
                local zone_name
                for part in file_no_ext:gmatch("%S+")do
                    if i == 0 then
                        if     part == 'G1' then zone_name = 'F'
                        elseif part == 'G2' then zone_name = 'RT'
                        elseif part == 'G3' then zone_name = 'MF RR1'
                        elseif part == 'G4' then zone_name = 'MF RR2'
                        elseif part == 'G5' then zone_name = 'MF RR3'
                        elseif part == 'G6' then zone_name = 'P RR1'
                        elseif part == 'G7' then zone_name = 'P RR2'
                        elseif part == 'G8' then zone_name = 'P RR3'
                        end
                    end
                end
                samples[zone_name] = filename
            end
        end
    end

    -- Reset the instrument groups.
    instrument.groups:reset()

    local groups = {}
    for i=0,max_rr-1 do
        local group_name = 'note_with_pedal rr'..(i+1)
        create_group(groups, i, group_name)
    end

    for i=max_rr,(2 * max_rr)-1 do
        local group_name = 'note_without_pedal rr'..(i-max_rr+1)
        create_group(groups, i, group_name)
    end

    create_group(groups, i, 'release_triggers')
    create_group(groups, i, 'pedal_up')
    create_group(groups, i, 'pedal_down')

    for zone,filename in pairs(samples) do
        if (zone == 'RT') then
            setup_group(groups['release_triggers'], filename, layer_map['RT'])
        elseif (zone == 'F') then
            setup_group(groups['note_with_pedal rr1'], filename, layer_map['F'])
            setup_group(groups['note_with_pedal rr2'], filename, layer_map['F'])
            setup_group(groups['note_with_pedal rr3'], filename, layer_map['F'])
            setup_group(groups['note_without_pedal rr1'], filename, layer_map['F'])
            setup_group(groups['note_without_pedal rr2'], filename, layer_map['F'])
            setup_group(groups['note_without_pedal rr3'], filename, layer_map['F']) 
        elseif (zone == 'MF RR1') then
            setup_group(groups['note_with_pedal rr1'], filename, layer_map['MF'])
            setup_group(groups['note_without_pedal rr1'], filename, layer_map['MF'])
        elseif (zone == 'MF RR2') then
            setup_group(groups['note_with_pedal rr2'], filename, layer_map['MF'])
            setup_group(groups['note_without_pedal rr2'], filename, layer_map['MF'])
        elseif (zone == 'MF RR3') then
            setup_group(groups['note_with_pedal rr3'], filename, layer_map['MF']) 
            setup_group(groups['note_without_pedal rr3'], filename, layer_map['MF'])
        elseif (zone == 'P RR1') then
            setup_group(groups['note_with_pedal rr1'], filename, layer_map['P'])
            setup_group(groups['note_without_pedal rr1'], filename, layer_map['P'])
        elseif (zone == 'P RR2') then
            setup_group(groups['note_with_pedal rr2'], filename, layer_map['P'])
            setup_group(groups['note_without_pedal rr2'], filename, layer_map['P'])
        elseif (zone == 'P RR3') then
            setup_group(groups['note_with_pedal rr3'], filename, layer_map['P'])     
            setup_group(groups['note_without_pedal rr3'], filename, layer_map['P'])              
        end 
    end
end

print("The samples are located in " .. path)

-- Check for valid instrument.
if not instrument then
    print("The following error message informs you that the Creator Tools are not "..
          "focused on a Kontakt instrument. To solve this, load an instrument in "..
          "Kontakt and select it from the instrument dropdown menu on top.")
else 
    process_samples()
end
