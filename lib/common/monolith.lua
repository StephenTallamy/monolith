local layer_map = { 
    F = {
        vol_low            = 120,
        vol_high           = 127,
        start_bar          = 1326,
        start_bar_pedal    = 5
    }, 
    RT = {
        vol_low            = 1, 
        vol_high           = 127,
        start_bar          = 1539,
        start_bar_pedal    = 218
    },
    MF = {
        vol_low            = 96, 
        vol_high           = 119,
        start_bar          = 1633,
        start_bar_pedal    = 312   
    }, 
    P = {
        vol_low            = 1, 
        vol_high           = 95,
        start_bar          = 2102,
        start_bar_pedal    = 781 
    },
    PEDAL_DOWN = {
        vol_low            = 1, 
        vol_high           = 127,
        start_bar          = 1250
    },
    PEDAL_UP = {
        vol_low            = 1, 
        vol_high           = 127,
        start_bar          = 1253
    }
}

local note_map = {"C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"}

monolith = {
    max_rr             = 3,
    num_pedal_rr       = 5,
    num_zones          = 30,
    note_interval      = 3,
    min_note           = 21,
    start_note         = 21,
    flavour            = 'DEFAULT',
    sample_rate        = 48000,
    time_signature     = 4,
    bpm                = 115.2,
    files              = {},
    prefix             = {},
    using_split        = false,
    detailed_naming    = false,
    rt_boost_db        = 20,
    pedal_boost_db     = 5,
    note_duration_bars = 7,
    adsr = {
        attack = 0,
        decay = 32.8,
        release = 0.405,
        sustain = 0
    },

    configure = function(config)       
        if config.flavour then
            monolith.flavour = config.flavour
        end

        if type(config.filepath) == 'table' then
            monolith.files = config.filepath
        else
            monolith.files = {config.filepath}
        end

        if config.prefix then
            if type(config.prefix) == 'table' then
                monolith.prefix = config.prefix
            else
                monolith.prefix = {config.prefix}
            end
        else
            for i,sample_file in pairs(monolith.files) do
                local prefix = sample_file:match("([^/]*).wav$")
                table.insert(monolith.prefix, prefix)
            end
        end   

        if monolith.flavour == 'GIMP' then
            layer_map['F']['start_bar']        = 5
            layer_map['F']['start_bar_pedal']  = 1266
            layer_map['RT']['start_bar']       = 186
            layer_map['RT']['start_bar_pedal'] = 1446
            layer_map['MF']['start_bar']       = 276
            layer_map['MF']['start_bar_pedal'] = 1537
            layer_map['P']['start_bar']        = 771 
            layer_map['P']['start_bar_pedal']  = 2032
            layer_map['PEDAL_DOWN']['start_bar'] = 2530
            layer_map['PEDAL_UP']['start_bar']   = 2532
            monolith.max_rr = 4
            monolith.num_pedal_rr = 4 -- need to cross-check this
        end

        if monolith.flavour == 'SAME_PEDALS' then
            layer_map['F']['start_bar']  = layer_map['F']['start_bar_pedal']
            layer_map['RT']['start_bar'] = layer_map['RT']['start_bar_pedal']
            layer_map['MF']['start_bar'] = layer_map['MF']['start_bar_pedal']
            layer_map['P']['start_bar']  = layer_map['P']['start_bar_pedal']
        end

        if monolith.flavour == 'MVP' then
            monolith.max_rr = 1
            monolith.num_pedal_rr = 1
            monolith.note_interval = 7
            monolith.start_note = 24
            monolith.num_zones = 12
            layer_map['F']['vol_low'] = 96
            layer_map['MF']['vol_low'] = 0
            layer_map['MF']['vol_high'] = 95
            layer_map['F']['start_bar_pedal'] = 5
            layer_map['RT']['start_bar_pedal'] = 95
            layer_map['MF']['start_bar_pedal'] = 135
            layer_map['F']['start_bar']  = layer_map['F']['start_bar_pedal']
            layer_map['RT']['start_bar'] = layer_map['RT']['start_bar_pedal']
            layer_map['MF']['start_bar'] = layer_map['MF']['start_bar_pedal']
            layer_map['P'] = nil
        end

        if monolith.flavour == 'BASIC' then
            layer_map['F']['vol_low'] = 0
            layer_map['F']['start_bar']  = 5
            layer_map['MF'] = nil
            layer_map['P'] = nil
            layer_map['RT'] = nil
            layer_map['PEDAL_DOWN'] = nil
            layer_map['PEDAL_UP'] = nil
            monolith.bpm = 120
        end

        if config.bpm then
            monolith.bpm = config.bpm
        end

        if config.rt_boost_db then
            monolith.rt_boost_db = config.rt_boost_db
        end

        if config.pedal_boost_db then
            monolith.pedal_boost_db = config.pedal_boost_db
        end

        if config.using_split then
            monolith.using_split = config.using_split
        end

        if config.detailed_naming then
            monolith.detailed_naming = config.detailed_naming
        end

        if config.adsr then
            monolith.adsr = config.adsr
        end

        if config.note_duration_bars then
            monolith.note_duration_bars = config.note_duration_bars
        end

        if config.max_rr then
            monolith.max_rr = config.max_rr
        end

        if config.note_interval then
            monolith.note_interval = config.note_interval
        end

        if config.start_note then
            monolith.start_note = config.start_note
        end

        if config.min_note then
            monolith.min_note = config.min_note
        end

        if config.num_zones then
            monolith.num_zones = config.num_zones
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

    get_note_low = function (root)
        return math.max(root - monolith.note_interval + 1, monolith.min_note)
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
        if monolith.flavour == 'BASIC' then return monolith.note_duration_bars 
        elseif layer == 'RT' then return 2
        elseif monolith.flavour == 'GIMP' and layer == 'PEDAL_UP' then return 4
        elseif layer == 'PEDAL_UP' or layer == 'PEDAL_DOWN' then return 2  
        elseif monolith.flavour == 'GIMP' then return monolith.get_note_duration_bars_v1(note_number, layer)
        else   return monolith.get_note_duration_bars_v2(note_number, layer)
        end
    end,

    get_bars_between_pedals = function()
        return 6
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
        if monolith.flavour == 'BASIC' then return monolith.max_rr
        elseif layer == 'RT' or layer == 'F' or monolith.flavour == 'MVP' then return 1
        elseif monolith.flavour == 'GIMP' then return monolith.get_num_rr_v1(note_number, layer)
        else   return monolith.get_num_rr_v2(note_number, layer)
        end
    end,

    get_samples = function (bar_num)
        return math.floor((60 / monolith.bpm) * (bar_num - 1) * monolith.time_signature * monolith.sample_rate)
    end,

    get_file_name  = function (file_prefix, layer, root, note_low, note_high, vol_low, vol_high, rr, pedal)
        local sample_file = file_prefix
        if monolith.detailed_naming == true then
            sample_file = sample_file.."_r"..root..'_lk'..note_low..'_hk'..note_high..'_lv'..vol_low..'_hv'..vol_high.."_rr"..rr
        else
            sample_file = sample_file.."_"..layer.."_"..monolith.get_note_name(root).."_rr"..rr
        end

        if layer == 'RT' then
            sample_file = sample_file .. "_rt" 
        elseif layer == 'PEDAL_UP' then
            sample_file = sample_file .. "_pedal_up" 
        elseif layer == 'PEDAL_DOWN' then
            sample_file = sample_file .. "_pedal_down"             
        elseif pedal == true or monolith.flavour == 'SAME_PEDALS' or monolith.flavour == 'MVP' then
            sample_file = sample_file .. "_withpedal"
        else 
            sample_file = sample_file .. "_nopedal" 
        end
        sample_file = sample_file..".wav"
    
        return sample_file
    end
}

