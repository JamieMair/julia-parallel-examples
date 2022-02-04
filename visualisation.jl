import Base.Iterators: product
using CUDA
include("mandelbrot.jl")

function pixel_to_c((x,y); shiftx, shifty, scale)
    return (x-shiftx)*scale + (y-shifty)*scale*1im
end

function pixel_map(screenWidth, screenHeight)
    return collect(product(1:screenWidth, 1:screenHeight))
end

function create_mandelbrot(screenWidth, screenHeight; shiftx, shifty, scale)
    Gray.(mandelbrot.(pixel_to_c.(pixel_map(screenWidth, screenHeight); shiftx, shifty, scale)))'
end

function create_mandelbrot_threaded(screenWidth, screenHeight; shiftx, shifty, scale)
    map = pixel_map(screenWidth, screenHeight)
    mmap = zeros(Gray, screenWidth, screenHeight)
    Threads.@threads for i in eachindex(map)
        mmap[i] = mandelbrot(pixel_to_c(map[i]; shiftx, shifty, scale))
    end
    return mmap
end

function cuda_mapping!(out, c)
    for i in eachindex(out)
        @inbounds out[i] = mandelbrotgpu(c[i])
    end
    return nothing 
end

function create_mandelbrot_cuda(screenWidth, screenHeight; shiftx, shifty, scale)
    pm = cu(pixel_to_c.(pixel_map(screenWidth, screenHeight); shiftx, shifty, scale))
    out = CUDA.zeros(Float64, screenWidth, screenHeight)
    CUDA.@sync @cuda cuda_mapping!(out, pm)
    return Gray.(Array(out))
end

