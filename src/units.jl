module Units

@enum UnitOfLength m mm μm nm

const default_unit = μm
const current_unit = μm
const scale_wvl = 1.0   # with respect to μm

function set_unit_length(unit::UnitOfLength)
    current_unit = unit
    diff_int = Int(unit) - Int(default_unit)
    global scale_wvl = 10.0^(-3*diff_int)
end

function reset_units()
    global scale_wvl = 1.0
    global current_unit = μm
end

end
