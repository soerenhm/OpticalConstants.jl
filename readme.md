# Optical constants
Handy Julia package for reading optical data from [refractiveindex.info](https://refractiveindex.info/).


## Searching materials
Say we want to find all matches to Au (chemical formula for gold); we can write
```
using OpticalConstants

matches = ri_search("Au")
println(matches)
```
Several matches were found, returned as a vector of dictionaries (only a few of the keys are shown to save space):
```
[{"material" => "Au", "name" => "Johnson and Christy 1972: n,k 0.188-1.937 µm", "page" => "Johnson", ...}, {"material" => "Au", "name" => "McPeak et al. 2015: n,k 0.3-1.7 µm", "page" => "McPeak", ...}, ...]
```
From this list, we simply select the source(s) that we want. It's possible to narrow the search by providing an optional `page` argument during the search, e.g. `ri_search("Au", "Johnson")`.


## Loading materials
Reading the optical constants of a material is done using `load_ri`, which accepts one or several dictionaries returned from `ri_search`. To load the optical constants of gold (Au) from [Johnson and Christie](https://doi.org/10.1103/PhysRevB.6.4370), do
```
Au = load_ri(ri_search("Au", "Johnson"))
println(Au)
```
which displays
```
Au, Tabulated n-k (0.1879 - 1.937 μm); interpolation: Dierckx.Spline1D.
Ref: P. B. Johnson and R. W. Christy. Optical constants of the noble metals, <a href="https://doi.org/10.1103/PhysRevB.6.4370"><i>Phys. Rev. B</i> <b>6</b>, 4370-4379 (1972)</a>.
Comments: Room temperature.
```
The description tells us that the refractive index data of gold is tabulated, but interpolated using `Spline1D` from the [Dierckx package](https://github.com/kbarbary/Dierckx.jl).


## The complex refractive index
The real and imaginary parts of the complex refractive index of a material is obtained by calling `get_ri` and `get_ec`, respectively. As an example, let's gather 200 points of the complex refractive index equally spaced on the tabulated domain of Johnson and Christies measurements of gold (0.1873 - 1.937 μm).
```
λ = LinRange(bounds(Au)..., 200)
ri = get_ri(Au, λ)
ec = get_ec(Au, λ)
complex_n = ri .+ im*ec
```


## Units
The data from [refractiveindex.info](https://refractiveindex.info) assumes that wavelengths are supplied in μm. We can change this to, say nm, in the following way:
```
set_unit_length(Units.nm)
println(bounds(Au))
```
The print statement now yields
```
[187.9, 1937.0]
```
