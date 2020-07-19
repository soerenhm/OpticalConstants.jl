module OpticalConstants


import HTTP, YAML, Dierckx


include("units.jl")
import .Units: set_unit_length

include("ri_database.jl")


export
    Units,
    set_unit_length,

    RefractiveIndex,

    bounds,
    get_ri,
    get_ec,
    ri_search,
    load_ri

end # module
