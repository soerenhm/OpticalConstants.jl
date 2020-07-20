using OpticalConstants
import YAML
using PyPlot; pygui(true)


ri_lib_meta = OpticalConstants.ri_lib_meta


data_types = []
data_type_entry = []
for material = keys(ri_lib_meta)
    for match = ri_search(material)
        yaml_file = YAML.load(open(match["data"]))["DATA"][1]
        dt = yaml_file["type"]
        if !(dt in data_types)
             push!(data_types, dt)
             push!(data_type_entry, (material, match["page"], yaml_file))
        end
    end
end


function plot_ri(elem)
    ri = load_ri(first(ri_search(elem[1:2]...)))
    x = LinRange(bounds(ri)..., 1_000)
    figure()
    plot(x, get_ri(ri, x), label="ri")
    plot(x, get_ec(ri, x), label="ec")
    xlabel("λ (μm)")
    ylabel("Refractive index")
    title(string(ri.material, ", ", elem[2]))
    legend()
end


for entry = data_type_entry
    plot_ri(entry) # compare with plots on refractiveindex.info
end
