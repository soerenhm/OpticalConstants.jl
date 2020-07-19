

ri_data_path(parts::AbstractString...) = joinpath(@__DIR__, "..", "data", "refractiveindex.info", parts...)

const ri_lib_path = ri_data_path("library.yml")


function download_ri_file(url, filename)
    h = HTTP.request("GET", url)
    open(filename, "w") do io
        write(io, String(h.body))
    end
    return h
end

function download_ri_lib()
    url = "https://raw.githubusercontent.com/polyanskiy/refractiveindex.info-database/master/database/library.yml"
    return download_ri_file(url, ri_lib_path)
end

function get_ri_lib()
    # global ri_lib_path
    isfile(ri_lib_path) || download_ri_lib()
    ri_lib = YAML.load(open(ri_lib_path))

    # fix 'bug' in the library.yml
    fix_keys = Dict("CO" => "CO1")
    _ri_lib = copy(ri_lib)

    for (i, ri_type) = enumerate(ri_lib)
        for (j, ri_material) = enumerate(ri_type["content"])
            haskey(ri_material, "BOOK") || continue

            name = ri_material["BOOK"]
            if name in keys(fix_keys)
                _ri_lib[i]["content"][j]["BOOK"] = fix_keys[name]
            end
        end
    end

    return _ri_lib
end


const ri_lib = get_ri_lib()



"""
    download_ri_database(; force_download::Bool, verbose::Bool) -> Dict

Downloads the refractiveindex.info database from Github to the local drive.
Returns search-indexing metadata.

If `force_download` is false (default), files that already exists on the hard
drive will not be downloaded again.
"""
function download_ri_database(; force_download=false, verbose=true)
    verbose && println("Downloading refractiveindex.info database from: https://github.com/polyanskiy/refractiveindex.info-database/tree/master/database/data...\n")

    ri_lib_meta = Dict{String,Vector{Dict{String,String}}}()

    _time = @elapsed for (shelf_index, ri_type) = enumerate(ri_lib)
        shelf = ri_type["SHELF"]
        shelf != "3d" || continue

        isdir(ri_data_path(shelf)) || mkdir(ri_data_path(shelf))

        for (material_index, ri_material) = enumerate(ri_type["content"])
            haskey(ri_material, "content") || continue
            haskey(ri_material, "BOOK") || continue

            chemical_formula = ri_material["BOOK"]
            material_folder = ri_data_path(shelf, chemical_formula)
            isdir(material_folder) || mkdir(material_folder)    # I think this line is unnecessary.
            ri_lib_meta[chemical_formula] = Vector{String}()

            for (entry, ri_datum) = enumerate(ri_material["content"])
                haskey(ri_datum, "data") || continue

                data_path = ri_data_path(normpath(ri_datum["data"]))
                github_url = string("https://raw.githubusercontent.com/polyanskiy/refractiveindex.info-database/master/database/data/", ri_datum["data"])
                github_url = replace(github_url, " " => "%20")  # `download` does not handle whitespace correctly.

                isdir(dirname(data_path)) || mkpath(dirname(data_path))

                if force_download
                    download_ri_file(github_url, data_path)
                else
                    isfile(data_path) || download_ri_file(github_url, data_path)
                end

                push!(ri_lib_meta[chemical_formula],
                        Dict("name" => ri_datum["name"],
                             "page" => string(ri_datum["PAGE"]),
                             "data" => data_path, "github" => github_url))
            end
        end
    end
    verbose && println("Download complete after $(_time) seconds.")

    YAML.write_file(ri_data_path("ri_lib_meta.yml"), ri_lib_meta)
    return ri_lib_meta
end

const ri_lib_meta = download_ri_database(; verbose=false)



"""
    ri_search(chemical_formula::AbstractString) -> Vector

Returns all matches to refractive index data of `chemical_formula`.
"""
function ri_search(chemical_formula::AbstractString)
    # global ri_lib_meta
    if haskey(ri_lib_meta, chemical_formula)
        matches = copy(ri_lib_meta[chemical_formula])
        for match = matches
            match["material"] = chemical_formula
        end
        return matches
    end
    println("Material not found; returning `nothing`...")
    return nothing
end

"""
    ri_search(chemical_formula::AbstractString, page::AbstractString) -> Vector

Match refractive index data with a given source, e.g. `ri_search("Ag", "Johnson")`.
"""
function ri_search(chemical_formula::AbstractString, page::AbstractString)
    all_matches = ri_search(chemical_formula)
    if !isnothing(all_matches)
        matches = Vector{eltype(all_matches)}()
        for match = all_matches
            if occursin(page, match["page"])
                push!(matches, match)
            end
        end
        return matches
    end
end


# ============================================================================ #

# supertype for various types of refractive index data
abstract type RIDataType end

get_ri(d::RIDataType, x::AbstractArray) = map(xi -> get_ri(d, xi), x)
get_ec(d::RIDataType, x::AbstractArray) = map(xi -> get_ec(d, xi), x)


#====================
    Tabulated nk
====================#
struct tabulated_nk{I} <: RIDataType
    data::Array{Float64,2}
    ri_interp::I
    ec_interp::I
end

tabulated_nk(data::Array{Float64,2}) =
        tabulated_nk(data, Dierckx.Spline1D(data[:,1],data[:,2]),
                           Dierckx.Spline1D(data[:,1],data[:,3]))

bounds(d::tabulated_nk) = [d.data[1,1], d.data[end,1]]
get_ri(d::tabulated_nk, x::Number) = Dierckx.evaluate(d.ri_interp, x)
get_ec(d::tabulated_nk, x::Number) = Dierckx.evaluate(d.ec_interp, x)

Base.show(io::IO, d::tabulated_nk) = print(io, "Tabulated n-k (", bounds(d)[1], " - ", bounds(d)[2], " μm); interpolation: ", typeof(d.ri_interp))

# Implement also: `tabulated_n` (k = 0?) and `tabulated_k` (n = 1?)


#====================
    Sellmeier 1
====================#
struct formula_1 <: RIDataType
    coeffs::Vector{Float64}
    bounds::Tuple{Float64,Float64}
end

bounds(f::formula_1) = [f.bounds...]

function get_ri(f::formula_1, x::Number)
    C = f.coeffs
    rhs = C[1]
    for i = 2:2:length(C)-1
        rhs += C[i]*x^2/(x^2 - C[i+1]^2)
    end
    return sqrt(1 + rhs)
end

get_ec(formula_1, x::Number) = zero(x)

Base.show(io::IO, ::formula_1) = print(io, "Sellmeier 1")


#===================
    Sellmeier 2
===================#
struct formula_2 <: RIDataType
    coeffs::Vector{Float64}
    bounds::Tuple{Float64,Float64}
end

bounds(f::formula_2) = [f.bounds...]

function get_ri(f::formula_2, x::Number)
    C = f.coeffs
    rhs = C[1]
    for i = 2:2:length(C)-1
        rhs += C[i]*x^2/(x^2 - C[i+1])
    end
    return sqrt(1 + rhs)
end

get_ec(::formula_2, x::Number) = zero(x)

Base.show(io::IO, ::formula_2) = print(io, "Sellmeier 2")



struct RefractiveIndex{T<:RIDataType}
    data::T
    material::String
    comments::String
    reference::String
    specs::Dict{Any,Any}
end

bounds(ri::RefractiveIndex) =  Units.length_from_micron(bounds(ri.data))
get_ri(ri::RefractiveIndex, x) = get_ri(ri.data, Units.length_to_micron(x))
get_ec(ri::RefractiveIndex, x) = get_ec(ri.data, Units.length_to_micron(x))

Base.show(io::IO, ri::RefractiveIndex) = print(io, ri.material, ", ref: ", ri.reference, ".")
function Base.show(io::IO, ::MIME"text/plain", ri::RefractiveIndex)
    print(io, ri.material, ", ", ri.data, ".")
    print(io, "\n", "Ref: ", ri.reference, ".")
    isempty(ri.comments) || print(io, "\n", "Comments: ", ri.comments, ".")
    isempty(ri.specs) || print(io, "\n", "Specs: ", ri.specs, ".")
end



function _tabulated_nk(data::Dict)
    lines = split(data["data"], "\n")
    N = length(lines)-1         # last line is empty
    data_array = zeros(N, 3)
    for i = 1:N
        data_array[i,:] .= parse.(Float64, split(lines[i]))
    end
    return tabulated_nk(data_array)
end

function _formula_1(data::Dict)
    bounds = parse.(Float64, split(data["wavelength_range"], " "))
    coeffs = parse.(Float64, split(data["coefficients"], " "))
    return formula_1(coeffs, tuple(bounds...))
end

_formula_2 = _formula_1

_ri_constructors = Dict(
    "tabulated nk" => _tabulated_nk,
    "formula 1" => _formula_1,
    "formula 2" => _formula_2,
)


function RefractiveIndex(ri_dict::Dict, material::AbstractString)
    _ri_data, = ri_dict["DATA"]
    type = _ri_data["type"]
    ri_data = _ri_constructors[type](_ri_data)
    comments = haskey(ri_dict, "COMMENTS") ? ri_dict["COMMENTS"] : ""
    references = haskey(ri_dict, "REFERENCES") ? ri_dict["REFERENCES"] : ""
    specs = haskey(ri_dict, "SPECS") ? ri_dict["SPECS"] : Dict()
    return RefractiveIndex(ri_data, material, comments, references, specs)
end


load_ri(ri_match::Dict) = RefractiveIndex(YAML.load(open(ri_match["data"])), ri_match["material"])

function load_ri(ri_matches::AbstractArray)
    if length(ri_matches) == 1
        return load_ri(first(ri_matches))
    end
    return [load_ri(ri_match) for ri_match = ri_matches]
end
