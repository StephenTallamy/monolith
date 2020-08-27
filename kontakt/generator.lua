local num_zones       = 29
local note_interval   = 3
local min_note        = 21
local sample_rate     = 48000
local time_signature  = 4
local bpm             = 115.2

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

local path = scriptPath .. filesystem.preferred("/samples/")
print("The samples are located in " .. path)

-- Check for valid instrument.
if not instrument then
    print("The following error message informs you that the Creator Tools are not "..
          "focused on a Kontakt instrument. To solve this, load an instrument in "..
          "Kontakt and select it from the instrument dropdown menu on top.")
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
    local bar                = start_bar
    for i=0,num_zones-1 do
        local zone         = Zone()
        local sample_start = math.floor((60 / bpm) * (bar - 1) * time_signature * sample_rate)
        local sample_end   = math.floor((60 / bpm) * (bar + note_duration_bars - 2) * time_signature * sample_rate)
        print('Bar In '..bar..' Note '..root..' Start '..sample_start.. ' End '..sample_end)        
        
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
        bar = bar + note_duration_bars
    end
end   

-- Declare an empty table which we will fill with the samples.
local samples = {}

local max_rr = 0
for _,p in filesystem.directoryRecursive(path) do
    if filesystem.isRegularFile(p) then
      if filesystem.extension(p) == '.wav' or filesystem.extension(p) == '.aif' or filesystem.extension(p) == '.aiff' then
        local filename = filesystem.filename(p)
        local file_no_ext = filename:match("(.+)%..+")
        local i = 0
        local zone_name
        local rr = 1
        for part in file_no_ext:gmatch("%S+")do
          if i == 0 then
            zone_name = part
          elseif i == 1 then
            rr = tonumber(string.match(part, '%d'))
            if rr > max_rr then
                max_rr = rr
            end
          end
          i = i + 1
        end
        if samples[zone_name] == nil then
            samples[zone_name] = {}
        end
        samples[zone_name][rr] = filename
      end
    end
end

-- Reset the instrument groups.
instrument.groups:reset()

local groups = {}
for i=0,max_rr-1 do
    local group_name = 'RR'..(i+1)
    create_group(groups, i, group_name)
end

create_group(groups, i, 'RT')

for zone,v in pairs(samples) do
    if (zone == 'RT') then
        for _,file in pairs(v) do
            setup_group(groups['RT'], file, layer_map['RT'])   
        end   
    else 
        local num_rr = 0
        local last_file = nil
        for i,file in pairs(v) do
            local group_name = 'RR'..i
            local layer = layer_map[zone]
            if layer ~= nil then
                setup_group(groups[group_name], file, layer)
                num_rr = num_rr + 1
            end
            last_file = file
        end
        if num_rr < max_rr then
            print('Missing RR for '..zone..' duplicating with '..last_file)
            for i=num_rr+1,max_rr do
                local group_name = 'RR'..i
                local layer = layer_map[zone]
                if layer ~= nil then
                    setup_group(groups[group_name], last_file, layer)
                end
            end
        end
    end   
end
