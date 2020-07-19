# Optical constants
Handy Julia package for reading optical data from [refractiveindex.info](https://refractiveindex.info/).


## Searching materials
Say we want to find all matches to Au (chemical formula for gold). You would write:
```
using OpticalConstants

matches = ri_search("Au")
println(matches)
```
We several matches were found, returned as a vector of dictionaries (we only show a couple of the keys):
```
[{"material" => "Au", "name" => "Johnson and Christy 1972: n,k 0.188-1.937 µm", "page" => "Johnson", ...}, {"material" => "Au", "name" => "McPeak et al. 2015: n,k 0.3-1.7 µm", "page" => "McPeak", ...}, ...]
```
Select the source you want from this list; you can also narrow the search by providing the optional `page` argument to during the search: `ri_search("Au", "Johnson")`.


## Loading materials
Reading the optical constants of a material is done using `load_ri`, which accepts a dictionary returned from `ri_search`. To load the optical constants of gold (Au) from Johnson and Christie, do
```
Au = load_ri(ri_search("Au", "Johnson"))
println(Au)
```
displays
```
Au, Tabulated n-k (0.1879 - 1.937 μm); interpolation: Dierckx.Spline1D.
Ref: P. B. Johnson and R. W. Christy. Optical constants of the noble metals, <a href="https://doi.org/10.1103/PhysRevB.6.4370"><i>Phys. Rev. B</i> <b>6</b>, 4370-4379 (1972)</a>.
Comments: Room temperature.
```
The description tells us that the refractive index data of gold is tabulated, but interpolated using `Spline1D` from the [Dierckx package](https://github.com/kbarbary/Dierckx.jl).


## The complex refractive index
The real and imaginary parts of the complex refractive index of a material is obtained by calling `get_ri` and `get_ec`, respectively. Let's gather 200 points equally spaced within the tabulated domain.
```
λ = LinRange(bounds(Au)..., 200)
complex_n = get_ri(Au, λ) .+ im*get_ec(Au, λ)
```


## Units
The data from [refractiveindex.info](https://refractiveindex.info) assumes that wavelengths are supplied in μm. We can change this to nm in the following way:
```
set_unit_length(Units.nm)
println(bounds(Au))
```
The print statement now yields
```
[187.9, 1937.0]
```
