module Units


# Units of length
const km = 1e3
const m = 1.0
const cm = 1e-2
const mm = 1e-3
const μm = 1e-6
const nm = 1e-9
const Å = 1e-10


const default_unit = μm
const current_unit = Ref(μm)
const scale_wvl = Ref(1.0)


function set_unit_length(unit::Real)
    current_unit[] = unit
    scale_wvl[] = unit / default_unit
    return nothing
end

function reset_units()
    scale_wvl[] = 1.0
    current_unit[] = μm
end


length_to_micron(x) = scale_wvl[] * x
length_from_micron(x) = x / scale_wvl[]
# length_to_micron(x) = (global scale_wvl; scale_wvl * x)
# length_from_micron(x) = (global scale_wvl; x / scale_wvl)


export set_unit_length

end
