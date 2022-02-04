using Random
using Plots
using BenchmarkTools
import BSON: @load, load

# Example 1 - Embarassingly Parallel Problem

# A problem of finding the distribution of a random walk after T steps.
function generate_walk_no_memory(T)
    x = zero(typeof(T))
    for _ in 1:T
        x += rand((-1, 1))
    end
    return x
end
function generate_distribution!(preallocated_array, T)
    @inbounds for i in eachindex(preallocated_array)
        preallocated_array[i] = generate_walk_no_memory(T)
    end
    return nothing
end
# A function just to generate some nice plots
function plot_distribution(dist, T)
    plt = histogram(dist, label="T=$T")
    xlabel!("Final Position")
    ylabel!("Frequency")
    return plt
end

# Let's time this code and see how long it takes to run.

# ----EXAMPLE----
T = 100;
n_samples = 1000000;
final_distribution = zeros(Int, n_samples);
@btime generate_distribution!(final_distribution, T);
# 359.521 ms (0 allocations: 0 bytes)
display(plot_distribution(final_distribution, T))

# In order to improve this, let's speed it up with Threading.
# Threading is a really easy way to speed up EP problems. The code all runs within the same process and hence all the different "workers" share the same memory. Threading has a low-memory footprint and a reasonbly small overhead, so can be used for fast tasks that need to be repeated many times.
# In Julia, making your code use threading is as simple as using the Threads.@threads macro
function generate_distribution_threaded!(final_distribution, T)
    @inbounds Threads.@threads for i in eachindex(final_distribution)
        final_distribution[i] = generate_walk_no_memory(T)
    end
    return nothing
end

# ----EXAMPLE----
@btime generate_distribution_threaded!(final_distribution, T);
# 93.101 ms (44 allocations: 7.63 MiB)

# Notice that the time is actually much faster, around 3-4x faster. My computer actually has 4 cores. However, it also has hyper-threading which allows a single core to process two threads at the same time, which makes it so we can view this as having effectively, 8 different workers. Why is this not 4x faster?
# One can also see that the threaded version allocated a lot more memory, this is because threads need memory to communicate with one another, and so the threading itself uses the memory. You don't really have much control over this.

# To answer this, we need to look at the bigger picture and see how the time scales with the number of samples.
function time_function(fn, params...; repeats = 5)
    min_time = Inf64
    for _ in 1:repeats
        new_time = @elapsed fn(params...)
        min_time = min(new_time, min_time)
    end
    return min_time
end
function compare_serial_vs_threaded_and_plot(T, samples; repeats = 5)
    min_times = ones(Float64, length(samples), 2).*1000.0
    # Serial times in 1st dim, threaded in 2nd dim. 
    for (i, n_samples) in enumerate(samples)
        dist_placeholder = zeros(Int, n_samples)
        min_times[i, 1] = time_function(generate_distribution!, dist_placeholder, T);
        min_times[i, 2] = time_function(generate_distribution_threaded!, dist_placeholder, T);
    end
    
    plt_log = plot(samples, min_times, labels = ["Serial" "Threaded"], legend=:topleft; markershape=[:utriangle :diamond], yscale=:log10, xscale=:log10)
    xlabel!("n")
    ylabel!("Time (s)")
    plt_linear = plot(samples, min_times, labels = ["Serial" "Threaded"], legend=:topleft; markershape=[:utriangle :diamond])
    xlabel!("n")
    ylabel!("Time (s)")
    return plot(plt_linear, plt_log, size=(800, 400)), min_times
end


# ----EXAMPLE----
samples = [1,2,4,8,16,32,64,128,256];
plt_serial_vs_threaded_short, _ = compare_serial_vs_threaded_and_plot(1000, samples;);
display(plt_serial_vs_threaded_short)

# Conclusion here is that you need a large enough task to parallelise over before you get a significant speedup with threading. This is especially true when the inner loop is especially small, sometimes it's just not worth it to parallelise, and Julia doesn't even bother.


# Let's try the same experiment, but using a much larger time, so that each sample takes longer to complete.

# ----EXAMPLE----
plt_serial_vs_threaded_long, min_times = compare_serial_vs_threaded_and_plot(1_000_000, samples;);
display(plt_serial_vs_threaded_long)

# This method of threading doesn't really scale well across multiple computers. What if your inner loop requires the full resources of a single computer? This is where multi-processing comes in. In order to use this, you need to start the julia REPL with a "-p n" flag, followed by the number of processes. It is usually best to have this number be less than or equal to the number of cores on your system. This will spawn up n copies of the Julia runtime that are independent processes. Each process knows almost nothing about the other, and they have no shared memory. This means that all communications need to be sent to each process, which means communications ports. Communication in multi-processing is a lot slower than in threading. This type of usage is beneficial for really long running tasks that require a lot of resources, and require little communication between processes. This is why you should restrict your uses to embarassingly parallel problems, or workflows that can be very computationally expensive, but not very memory intensive.

# ----EXAMPLE----

mp_results = load("mp_distributed_results.bson")
min_times = hcat(min_times, mp_results[:min_times])
@assert all(samples .== mp_results[:samples])
plt_serial_vs_threaded_vs_mp = plot(samples, min_times, labels = ["Serial" "Threaded" "MP"], legend=:topleft; markershape=[:utriangle :diamond], xscale=:log10, yscale=:log10)
xlabel!("n")
ylabel!("Time (s)")
display(plt_serial_vs_threaded_vs_mp)

# Example 2 - GPU programming!

# Let's try and use our original function, and speed up the process by using my GPU.
using CUDA

# Remember we used a preallocated array to store the results before? Let's do that again but copy it to the GPU.

function generate_distribution_cuda!(distribution, T)
    index = threadIdx().x
    stride = blockDim().x
    for i = index:stride:length(distribution)
        @inbounds distribution[i] = generate_walk_no_memory(T)
    end
    return nothing
end

function bench_cuda_dist!(distribution, T)
    CUDA.@sync begin
        @cuda threads=1024 generate_distribution_cuda!(distribution, T)
    end
    nothing
end

function measure_gpu_times(samples, T)
    min_times = zeros(Float64, length(samples))
    for (i, n) in enumerate(samples)
        placeholder_gpu = cu(zeros(Int32, n))
        min_times[i] = time_function(bench_cuda_dist!, placeholder_gpu, T)
    end
    return min_times
end

function threaded_vs_gpu_long()
    samples = 10 .^ collect(0: 8)
    T = 20
    function get_threaded_time(n_samples)
        dist_placeholder = zeros(Int32, n_samples)
        t = time_function(generate_distribution_threaded!, dist_placeholder, T);
        return t
    end
    cpu_threaded_times = get_threaded_time.(samples)
    gpu_times = measure_gpu_times(samples, T)

    return T, samples, cpu_threaded_times, gpu_times
end

function plot_threaded_gpu(T, samples, cpu_threaded_times, gpu_times)
    plt = plot(samples, cpu_threaded_times, label="Threaded"; markershape=:utriangle)
    plot!(samples, gpu_times, label="GPU"; markershape=:square, xscale=:log10, yscale=:log10)
    xlabel!("n")
    ylabel!("Time (s) for T=$T")
    return plt
end

T, cpu_vs_gpu_samples, cpu_threaded_times, gpu_times = threaded_vs_gpu_long();
plt_threaded_vs_gpu_long = plot_threaded_gpu(T, cpu_vs_gpu_samples, cpu_threaded_times, gpu_times);
display(plt_threaded_vs_gpu_long)


# Clearly this improvement is minimal. Let's take a look at a faster implementation.

function generate_distribution_arrays!(dist, cache, T)
    dist .= zero(eltype(dist))
    limit = convert(eltype(cache), 0.5);
    two = convert(eltype(dist), 2);
    elone = one(eltype(dist))
    for _ in 1:T
        rand!(cache)
        dist .+= two .* (cache .< limit) .- elone
    end
    nothing
end

function measure_array_times(samples, T)
    function measure_cpu(n)
        dist = zeros(Int32, n)
        cache = zeros(Float32, n)
        return time_function(generate_distribution_arrays!, dist, cache, T)
    end
    function measure_gpu(n)
        dist = cu(zeros(Int32, n))
        cache = cu(zeros(Float32, n))
        return time_function(generate_distribution_arrays!, dist, cache, T)
    end
    cpu_times = zeros(Float64, length(samples))
    gpu_times = zeros(Float64, length(samples))
    for (i, n) in enumerate(samples)
        cpu_times[i] = measure_cpu(n)
        gpu_times[i] = measure_gpu(n)
        # Save memory
        GC.gc()
        CUDA.reclaim()
    end
    return cpu_times, gpu_times
end

samples = 10 .^ collect(0: 8);
cpu_times_array, gpu_times_array = measure_array_times(samples, 20);

plt_threaded_vs_gpu_array = plot_threaded_gpu(20, samples, cpu_times_array, gpu_times_array);
display(plt_threaded_vs_gpu_array)

# One can clearly see here why you would use a GPU. You can effectively scale as long as you have memory to support it. The GPU is capable of processing millions of bits of data all at the same time. The main point to make here is that using a GPU is only really worth it if you are scaling up by a huge amount.