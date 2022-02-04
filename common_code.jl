function generate_walk_no_memory(T)
    x = 0
    for _ in 1:T
        x += rand((-1, 1))
    end
    return x
end