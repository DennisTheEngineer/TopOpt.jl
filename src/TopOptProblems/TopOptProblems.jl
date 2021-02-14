module TopOptProblems

using JuAFEM, StaticArrays, LinearAlgebra
using SparseArrays, Setfield, Requires
using ..TopOpt.Utilities
using ..TopOpt: PENALTY_BEFORE_INTERPOLATION
using ..Utilities: @forward_property
import Distributions

using VTKDataTypes

import JuAFEM: assemble!

abstract type AbstractTopOptProblem end

include("utils.jl")
include("grids.jl")
include("metadata.jl")
include("problem_types.jl")
include("multiload.jl")
include("elementmatrix.jl")
include("matrices_and_vectors.jl")
include("elementinfo.jl")
include("assemble.jl")
include("buckling.jl")

include(joinpath("IO", "IO.jl"))
using .InputOutput

include("Visualization/Visualization.jl")
using .Visualization

export RayProblem, PointLoadCantilever, HalfMBB, LBeam, TieBeam, InpStiffness, StiffnessTopOptProblem, AbstractTopOptProblem, GlobalFEAInfo, ElementFEAInfo, YoungsModulus, assemble, assemble_f!, RaggedArray, ElementMatrix, rawmatrix, bcmatrix, save_mesh, RandomMagnitude, MultiLoad

end # module
