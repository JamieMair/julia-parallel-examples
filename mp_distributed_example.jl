# Start julia with julia --project -p 8 -t 1 and then run the file in the REPL.
using Plots
using Distributed

@everywhere using Pkg;
@everywhere Pkg.activate(".");
@everywhere using BenchmarkTools;
@everywhere include("common_code.jl")

T = 1_000_000
# Precompile the function
@everywhere generate_walk_no_memory(10);



function measure_scaling(;repeats=5)
    samples = [1,2,4,8,16,32,64,128, 256];
    min_times = ones(Float64, length(samples)).*100000.0
    for (i, n) in enumerate(samples)
        mapping_array = T.*ones(Int, n)
        time_taken = @belapsed pmap($generate_walk_no_memory, $mapping_array);
        min_times[i] = time_taken
    end
    return samples, min_times
end

function plot_results(samples, time_taken)
    plt = plot(samples, time_taken, legend=false; markershape=:utriangle, linealpha=0.0)
    xlabel!("n")
    ylabel!("Time Taken (s)")
    return plt;
end

samples, min_times = measure_scaling();
import BSON: @save
@save "mp_distributed_results.bson" samples min_times