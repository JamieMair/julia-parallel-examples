using Random
# An example problem with many allocations
function example()
    x = zeros(10)
    for t in 1:20
        x .+= rand(10)
    end
    return x
end
# An example without any allocations, which mutates x - hence the !
function example2!(x, cache)
    x .= zero(eltype(x))
    for t in 1:20
        rand!(cache) # Fills the "cache" array with random numbers
        x .+= cache
    end
    return x
end

# You can hide the cache variable in the following way, but function will only work with an array of size 10.
begin # Begin block changes the scope so cache is not global
    cache = zeros(10) # Create the preallocated cache here
    function example3!(x) # Define your function that uses the cache, this is called a "closure"
        return example2!(x, cache)
    end

    # Export the function so you can use it in the main body.
    export example3!
end

# Benchmarking
using BenchmarkTools
@btime example()

# For preallocation you need to create the arrays
x = zeros(10)
test_cache = similar(x);
@btime example2!(x, test_cache)

# Third example only needs x, but will only work with arrays of size 10 - there are ways to make this more general but it illustrates the point.
@btime example3!(x)
