num_groups         = 8

num_zones          = 29
note_interval      = 3
sample_rate        = 48000
time_signature     = 4
bpm                = 115.2
note_duration_bars = 7
start_bar          = 1

local path = scriptPath .. filesystem.preferred("/samples/")
print("The samples are located in " .. path)

-- Check for valid instrument.
if not instrument then
    print("The following error message informs you that the Creator Tools are not "..
          "focused on a Kontakt instrument. To solve this, load an instrument in "..
          "Kontakt and select it from the instrument dropdown menu on top.")
end

function setup_group(group, idx)
    group.name =  'Group '..idx
    
    local root = 21
    local bar = start_bar
    for i=0,num_zones-1 do
        local zone         = Zone()
        local sample_start = math.floor((60 / bpm) * (bar - 1) * time_signature * sample_rate)
        local sample_end   = math.floor((60 / bpm) * (bar + note_duration_bars - 2) * time_signature * sample_rate)
        print('Bar In '..bar..' Note '..root..' Start '..sample_start.. ' End '..sample_end)        
        
        -- Set the zone root key, high range and low range to the same values thus confining the zone to a single note.
        zone.rootKey       = root
        zone.keyRange.low  = root - note_interval + 1
        zone.keyRange.high = root
        zone.sampleStart   = sample_start
        zone.sampleEnd     = sample_end

        zone.file = path..'G'..idx..'.wav'
        group.zones:add(zone)

        root = root + note_interval
        bar = bar + note_duration_bars
    end
end    

-- Reset the instrument groups.
instrument.groups:reset()

setup_group(instrument.groups[0], 1)

for i=1,num_groups-1 do
    local group = Group()
    setup_group(group, i+1)
    instrument.groups:add(group)
end

print(#instrument.groups)