local num_zones       = 30
local note_interval   = 3
local min_note        = 9
local sample_rate     = 48000
local time_signature  = 4
local bpm             = 115.2
local max_rr          = 4

local layer_map = { 
    F = {
        vol_low            = 120,
        vol_high           = 127,
        start_bar          = 1
    }, 
    MF = {
        vol_low            = 96, 
        vol_high           = 119,
        start_bar          = 272
    }, 
    P = {
        vol_low            = 1, 
        vol_high           = 95,
        start_bar          = 767
    },
    RT = {
        vol_low            = 1, 
        vol_high           = 127,
        start_bar          = 181
    }
}

local note_map = {"C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"}

function get_note_name(note_num)
   local idx = (note_num % 12) + 1
   local octave = math.floor(note_num / 12) - 1
   return note_map[idx]..octave
end

local path = scriptPath .. filesystem.preferred("/samples/")
local file = path..'Test Monolith.wav'

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

function get_note_duration_bars(note_number, layer)
    if     layer == 'RT'    then return 2
    elseif note_number < 24 then return 7 -- C1
    elseif note_number < 60 then return 6 -- C4
    elseif note_number < 72 then return 5 -- C5 
    elseif note_number < 84 then return 3 -- C6
    else   return 2
    end
end

function get_num_rr(note_number, layer)
    if     layer == 'RT' or layer == 'F' then return 1
    elseif note_number < 24 then return 1 -- C1
    elseif note_number < 36 then return 2 -- C2
    elseif note_number < 72 then return 4 -- C5 
    elseif note_number < 84 then return 3 -- C6
    else   return 2
    end
end

function setup_layer(groups, file, layer)
    local layer_info         = layer_map[layer]
    if layer_info == nil then
        print('Unknown layer '..layer)
        return 
    end
    local vol_low            = layer_info['vol_low']
    local vol_high           = layer_info['vol_high']
    local start_bar          = layer_info['start_bar']
    local root               = min_note
    local bar_in             = start_bar

    print('------------------------------------------------------------------------------')
    print(string.format("Layer %s Bar In %d Vol Low %d Vol High %d", layer, bar_in, vol_low, vol_high))
    print('------------------------------------------------------------------------------')
    for i=0,num_zones-1 do
        local num_rrs            = get_num_rr(root, layer)
        local note_duration_bars = get_note_duration_bars(root, layer)
        local note_name          = get_note_name(root)
        for rr=1,max_rr do
            local group_name   = 'RR'..rr
            if layer == 'RT' then
                group_name = 'RT'
            end
            local zone         = Zone()
            local note_bar_in  = bar_in + (((rr - 1) % num_rrs) * (note_duration_bars + 1))
            local note_bar_out = note_bar_in + note_duration_bars
            local sample_start = math.floor((60 / bpm) * (note_bar_in - 1) * time_signature * sample_rate)
            local sample_end   = math.floor((60 / bpm) * (note_bar_out - 1) * time_signature * sample_rate)
            
            print(string.format("Note %3s (%2d) Bar In %4d Bar Out %4d RR %d Bars %d Start %8d End %8d", note_name, root, note_bar_in, note_bar_out, rr, note_duration_bars, sample_start, sample_end))        
            
            zone.rootKey       = root
            zone.keyRange.low  = math.max(root - note_interval + 1, min_note)
            zone.keyRange.high = root
            zone.sampleStart   = sample_start
            zone.sampleEnd     = sample_end
            zone.velocityRange.low  = vol_low
            zone.velocityRange.high = vol_high
            
            local group = groups[group_name]
            zone.file = file
            group.zones:add(zone) 
            
            if layer == 'RT' then
                break
            end
        end

        root   = root + note_interval
        bar_in = bar_in + ((note_duration_bars + 1) * num_rrs)
    end
end  

function process_samples()

    -- Reset the instrument groups.
    instrument.groups:reset()

    local groups = {}
    for i=0,max_rr-1 do
        local group_name = 'RR'..(i+1)
        create_group(groups, i, group_name)
    end

    create_group(groups, i, 'RT')
    
    setup_layer(groups, file, 'F')
    setup_layer(groups, file, 'RT')
    setup_layer(groups, file, 'MF')
    setup_layer(groups, file, 'P')
end

print("The samples are located in ")
print(file)

-- Check for valid instrument.
if not instrument then
    print("The following error message informs you that the Creator Tools are not "..
          "focused on a Kontakt instrument. To solve this, load an instrument in "..
          "Kontakt and select it from the instrument dropdown menu on top.")
else 
    process_samples()
end
