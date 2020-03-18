using Gen, GenViz
using FunctionalCollections: PersistentVector
import Random

@gen (static) function datum(x::Float64, inlier_std::Float64,
                          outlier_std::Float64, slope::Float64, intercept::Float64)
    is_outlier::Bool = @trace(bernoulli(0.5), :z)
    std = is_outlier ? outlier_std : inlier_std
    mu = is_outlier ? 0. : x * slope + intercept
    y::Float64 = @trace(normal(mu, std), :y)
    return y
end

data = Map(datum)

@gen (static) function model(xs::Vector{Float64})
    n = length(xs)
    inlier_log_std::Float64 = @trace(normal(0, 2), :log_inlier_std)
    outlier_log_std::Float64 = @trace(normal(0, 2), :log_outlier_std)
    inlier_std = exp(inlier_log_std)
    outlier_std = exp(outlier_log_std)
    slope::Float64 = @trace(normal(0, 2), :slope)
    intercept::Float64 = @trace(normal(0, 2), :intercept)
    @trace(data(xs, fill(inlier_std, n), fill(outlier_std, n),
               fill(slope, n), fill(intercept, n)),
          :data)
end

function make_data_set(n)
    Random.seed!(1)
    prob_outlier = 0.5
    true_inlier_noise = 0.5
    true_outlier_noise = 5.0
    true_slope = -1
    true_intercept = 2
    xs = collect(range(-5, stop=5, length=n))
    ys = Float64[]
    for (i, x) in enumerate(xs)
        if rand() < prob_outlier
            y = randn() * true_outlier_noise
        else
            y = true_slope * x + true_intercept + randn() * true_inlier_noise
        end
        push!(ys, y)
    end
    (xs, ys)
end

@gen (static) function datum(x::Float64, inlier_std::Float64, outlier_std::Float64, slope::Float64, intercept::Float64)
    is_outlier::Bool = @trace(bernoulli(0.5), :z)
    std = is_outlier ? outlier_std : inlier_std
    mu = is_outlier ? 0. : x * slope + intercept
    y::Float64 = @trace(normal(mu, std), :y)
    return y
end

data = Map(datum)

@gen (static) function model(xs::Vector{Float64})
    n = length(xs)
    log_inlier_std::Float64 = @trace(normal(-1, 0.5), :log_inlier_std)
    inlier_std = exp(log_inlier_std)
    log_outlier_std::Float64 = @trace(normal(1, 1), :log_outlier_std)
    outlier_std = exp(log_outlier_std)
    slope::Float64 = @trace(normal(0, 2), :slope)
    intercept::Float64 = @trace(normal(0, 2), :intercept)
    ys::PersistentVector{Float64} = @trace(data(xs, fill(inlier_std, n), fill(outlier_std, n),
               fill(slope, n), fill(intercept, n)), :data)
    return ys
end

@gen function slope_proposal(prev)
    slope = prev[:slope]
    @trace(normal(slope, 0.5), :slope)
end

@gen function intercept_proposal(prev)
    intercept = prev[:intercept]
    @trace(normal(intercept, 0.5), :intercept)
end

@gen function inlier_std_proposal(prev)
    log_inlier_std = prev[:log_inlier_std]
    @trace(normal(log_inlier_std, 0.1), :log_inlier_std)
end

@gen function outlier_std_proposal(prev)
    log_outlier_std = prev[:log_outlier_std]
    @trace(normal(log_outlier_std, 0.1), :log_outlier_std)
end

@gen function is_outlier_proposal(prev, i::Int)
    prev = prev[:data => i => :z]
    @trace(bernoulli(prev ? 0.0 : 1.0), :data => i => :z)
end

function trace_to_dict(t)
    args = get_args(t)
    num_data = length(args[1])
    Dict("slope" => t[:slope], "intercept" => t[:intercept],
        "inlier_std" => exp(t[:log_inlier_std]),
        "outlier_std" => exp(t[:log_outlier_std]),
        "outliers" => [t[:data => i => :z] for i in 1:num_data])
end

function do_inference_uncertainty(xs, ys, n_chains, num_iters, v)
    observations = DynamicChoiceMap()
    for (i, y) in enumerate(ys)
        observations[:data => i => :y] = y
    end

    traces = Array{Any}(undef, n_chains)

    for n=1:n_chains
        # initial trace
        (traces[n], _) = generate(model, (xs,), observations)
        putTrace!(v, n, trace_to_dict(traces[n]))
    end

    for i=1:num_iters
        # steps on the parameters
        for j=1:5
            for n=1:n_chains
                (traces[n], _) = mh(traces[n], slope_proposal, ())
                (traces[n], _) = mh(traces[n], intercept_proposal, ())
                (traces[n], _) = mh(traces[n], inlier_std_proposal, ())
                (traces[n], _) = mh(traces[n], outlier_std_proposal, ())
                putTrace!(v, n, trace_to_dict(traces[n]))
            end
        end

        # step on the outliers
        for n=1:n_chains
            for j=1:length(xs)
                (traces[n], _) = mh(traces[n], is_outlier_proposal, (j,))
            end
            putTrace!(v, n, trace_to_dict(traces[n]))
        end
    end
end

(xs, ys) = make_data_set(200)


server = VizServer(8000)
v = Viz(server, joinpath(@__DIR__, "vue/dist"), [xs, ys])
sleep(0.5)
openInBrowser(v)
sleep(3)

Gen.load_generated_functions()
do_inference_uncertainty(xs, ys, 4, 10, v)
saveToFile(v, joinpath(@__DIR__, "output.html"))
readline(stdin)
