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
example3! = let cache=zeros(10) # cache defined in local scope
    function example3!(x) # Define your function that uses the cache, this is called a "closure"
        return example2!(x, cache) # cache is used and "closed" in the function definition.
    end
    example3! # Return the function to be assigned to example3! in the global scope
end

# This is the same as 3, but reallocates the cache for different sizes of x
example4! = let cache=zeros(10)
    function example4!(x)
        if eltype(cache) != eltype(x) || length(cache) != length(x)
            cache = similar(x)
        end
        return example2!(x, cache)
    end
    example4!
end

# Benchmarking
using BenchmarkTools
@btime example()

# For preallocation you need to create the arrays
x = zeros(10)
test_cache = similar(x);
@btime example2!(x, test_cache);

# Third example only needs x, but will only work with arrays of size 10 - there are ways to make this more general but it illustrates the point.
@btime example3!(x);

# Fourth example, but can work with any x.
@btime example4!(x);
y = zeros(1000)
example4!(y) # Create the new cache
@btime example4!(y); # Not sure why this allocates, but it is not that much
