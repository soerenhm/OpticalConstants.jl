import HTTP, YAML



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
    isfile(ri_lib_path) || download_ri_lib()
    ri_lib = YAML.load(open(ri_lib_path))

    ## fix 'bugs' in the library.yml

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
Returns search-indexing information.

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


const ri_lib_meta = download_ri_database()




function ri_search(chemical_formula::AbstractString)
    if haskey(ri_lib_meta, chemical_formula)
        return ri_lib_meta[chemical_formula]
    end
    println("Material not found; returning `nothing`...")
    return nothing
end

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
