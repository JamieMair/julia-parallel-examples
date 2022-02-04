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
        rand!(cachc) # Fills the "cache" array with random numbers
        x .+= cache
    end
    return x
end

# You can hide the cache variable in the following way, but function will only work with an array of size 10.
example3 = begin
    cache = zeros(10)
    function example3(x)
        x.=zero(eltype(x))
        # Can also do some checks here to make sure the cache variable is appropriate.
        for t in 1:20
            rand!(cache)
            x.+=cache
        end
        return x
    end
    return example3
end