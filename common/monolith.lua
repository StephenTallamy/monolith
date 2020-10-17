local sample_rate     = 48000
local time_signature  = 4
local bpm             = 115.2

local layer_map = { 
    F = {
        vol_low            = 120,
        vol_high           = 127,
        start_bar          = 5,
        start_bar_pedal    = 1357
    }, 
    RT = {
        vol_low            = 1, 
        vol_high           = 127,
        start_bar          = 218,
        start_bar_pedal    = 1563
    },
    MF = {
        vol_low            = 96, 
        vol_high           = 119,
        start_bar          = 312,
        start_bar_pedal    = 1657   
    }, 
    P = {
        vol_low            = 1, 
        vol_high           = 95,
        start_bar          = 781,
        start_bar_pedal    = 2126 
    },
    PEDAL_DOWN = {
        vol_low            = 1, 
        vol_high           = 127,
        start_bar          = 2530
    },
    PEDAL_UP = {
        vol_low            = 1, 
        vol_high           = 127,
        start_bar          = 2532
    }
}

local note_map = {"C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"}

monolith = {
    max_rr          = 3,
    num_pedal_rr    = 5,
    num_zones       = 30,
    note_interval   = 3,
    min_note        = 21,
    flavour         = 'DEFAULT',

    set_flavour = function(flavour)
        monolith.flavour = flavour

        if flavour == 'GIMP' then
            layer_map['F']['start_bar_pedal']  = 1266
            layer_map['RT']['start_bar']       = 186
            layer_map['RT']['start_bar_pedal'] = 1446
            layer_map['MF']['start_bar']       = 276
            layer_map['MF']['start_bar_pedal'] = 1537
            layer_map['P']['start_bar']        = 771 
            layer_map['P']['start_bar_pedal']  = 2032
            monolith.max_rr = 4
            monolith.num_pedal_rr = 4 -- need to cross-check this
        end
        
        if flavour == 'MODULAR' then
            -- no P layer in MODULAR and no notes without pedal
            layer_map['F']['vol_low']          = 97 
            layer_map['F']['start_bar_pedal']  = 5
            layer_map['RT']['start_bar']       = 186
            layer_map['MF']['start_bar']       = 276
            layer_map['MF']['start_bar_pedal'] = 276
            layer_map['MF']['vol_low']         = 0 
            layer_map['MF']['vol_high']        = 96    
            monolith.max_rr = 4
        end
    end,

    get_layer_info = function(layer)
        return layer_map[layer]
    end,

    get_note_name = function (note_num)
        local idx = (note_num % 12) + 1
        local octave = math.floor(note_num / 12) - 2
        return note_map[idx]..octave
    end,

    get_note_duration_bars_v1 = function (note_number, layer)
        if note_number < 36 then return 7 -- C1
        elseif note_number < 72 then return 6 -- C4
        elseif note_number < 84 then return 5 -- C5 
        elseif note_number < 96 then return 3 -- C6
        else   return 2
        end
    end,

    get_note_duration_bars_v2 = function (note_number, layer)
        if note_number < 36 then return 8 -- C1
        elseif note_number < 72 then return 7 -- C4
        elseif note_number < 84 then return 6 -- C5 
        elseif note_number < 96 then return 4 -- C6
        else   return 3
        end
    end,

    get_note_duration_bars = function (note_number, layer)
        if     layer   == 'RT'   then return 2
        elseif monolith.flavour == 'GIMP' or monolith.flavour == 'MODULAR' then return monolith.get_note_duration_bars_v1(note_number, layer)
        else   return monolith.get_note_duration_bars_v2(note_number, layer)
        end
    end,

    get_num_rr_v1 = function (note_number, layer)
        if note_number < 36 then return 1 -- C1
        elseif note_number < 48 then return 2 -- C2
        elseif note_number < 84 then return 4 -- C5
        elseif note_number < 96 then return 3 -- C6
        else   return 2
        end
    end,

    get_num_rr_v2 = function (note_number, layer)
        if note_number < 36 then return 1 -- C1
        elseif note_number < 48 then return 2 -- C2
        elseif note_number < 96 then return 3 -- C6
        else   return 1
        end
    end,

    get_num_rr = function (note_number, layer)
        if     layer == 'RT' or layer == 'F' then return 1
        elseif monolith.flavour == 'GIMP' or monolith.flavour == 'MODULAR' then return monolith.get_num_rr_v1(note_number, layer)
        else   return monolith.get_num_rr_v2(note_number, layer)
        end
    end,

    get_samples = function (bar_num)
        return math.floor((60 / bpm) * (bar_num - 1) * time_signature * sample_rate)
    end,

    get_file_name  = function (file_prefix, layer, root, note_low, note_high, vol_low, vol_high, rr)
        local sample_file = file_prefix.."_r"..root..'_lk'..note_low..'_hk'..note_high..'_lv'..vol_low..'_hv'..vol_high.."_rr"..rr
        if layer == 'RT' then
            sample_file = sample_file .. "_rt" 
        elseif layer == 'PEDAL_UP' then
            sample_file = sample_file .. "_pedal_up" 
        elseif layer == 'PEDAL_DOWN' then
            sample_file = sample_file .. "_pedal_down"             
        elseif pedal == true then
            sample_file = sample_file .. "_withpedal"
        else 
            sample_file = sample_file .. "_nopedal" 
        end
        sample_file = sample_file..".wav"
    
        return sample_file
    end
}

