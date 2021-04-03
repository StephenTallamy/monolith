get_declare = function (groups, variable) 
    local num_groups = 0
    local variable_script = ""
    for k, v in pairs(groups) do
        if num_groups > 0 then
            variable_script = variable_script .. ','
        end
        variable_script = variable_script .. v
        num_groups = num_groups + 1
    end

    variable_script = "    declare %"..variable.."[" .. num_groups .. "] := ("..variable_script..")"
    return variable_script
end