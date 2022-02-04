function example()
    x = zeros(10)
    for t in 1:20
        x .+= rand(10)
    end
    return x
end

function example2()
    cache = zeros(10)
    function fun(x)
        for t in 1:20
            rand!(cache)
            x .+= cache
        end
        return nothing
    end
    return fun
end