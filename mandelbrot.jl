function mandelbrot(c; max_steps=256.0, max_length=2.0)
    z = 0 + 0im
    for n = one(typeof(max_steps)):max_steps
        z = z*z+c
        if abs2(z) > max_length*max_length
            return n/max_steps
        end
    end
    return zero(typeof(max_steps))
end

function mandelbrotxy(x,y)
    max_steps=256
    max_length=2
    c= x+y*im
    z = 0 + 0im
    for n = 1:max_steps
        z = z*z+c
        if abs2(z) > max_length*max_length
            return n
        end
    end
    return 0
end

function mandelbrotgpu(c)
    max_steps=256
    max_length=2.0
    z = 0 + 0im
    for n = 1.0:max_steps
        z = z*z+c
        if abs2(z) > max_length*max_length
            return n/max_steps
        end
    end
    return 0.0
end