# GenViz

GenViz helps visualize and debug inference algorithms written in the [Gen](https://github.com/probcomp/Gen) probabilistic programming language.

## Running the example visualization

```
cd example/
JULIA_PROJECT=. julia run_example.jl
```
The script will launch a browser window, in which you can view the running visualization.

## Using GenViz

### Step 1: Create a custom renderer for your model
The first step to using GenViz in your Gen project is to create a GenViz-compatible _trace renderer_: a directory of HTML, JavaScript, and CSS files that together describe how a single execution trace of a generative model should be visualized. 

Although this repository provides generic trace renderers that may be suitable for some purposes, most users will want to customize the renderer to capture model-specific structure. (For example, in a model of an agent in an environment, a good renderer would draw the environment and the agent.) We provide a general template for writing custom renderers, and instructions for doing so further below.

### Step 2: Initialize and interactively update the visualization from Gen
You can use GenViz from a Julia script or from an IJulia notebook. In either case, you'll want to begin by starting a "visualization server" on some open port (e.g. port 8000).

```julia
using GenViz
viz_server = VizServer(8000) # or some other port
```

You can then create one or more `Viz` objects, which each represent a single figure or visualization. To create one, you'll need to supply the global `VizServer`, a path to the trace renderer created in Step 1, and any custom initialization parameters your renderer expects. For example, in a linear regression program, we might pass the `x` and `y` coordinates of all observed points as initialization arguments, as they will not vary during the course of inference:

```julia
xs = collect(0:0.1:10);
ys = sin.(xs);
v = Viz(viz_server, joinpath(@__DIR__, "my-renderer/dist"), [xs, ys])
```

This creates a visualization object `v` that can be manipulated using the `putTrace!` and `deleteTrace!` methods. In an MCMC algorithm, for example, you might initialize several chains and put them all into the visualization:

```julia
traces = Array{Any}(undef, n_chains)
for n=1:n_chains
    (traces[n], _) = initialize(model, model_inputs, observations)
    putTrace!(v, n, trace_to_dict(traces[n]))
end
```

Then, as inference proceeds, you might periodically call `putTrace!` to update each chain with its new state.

The `putTrace!` and `deleteTrace!` operators modify the visualization's state. GenViz provides a few ways of actually seeing and interacting with the visualization as it is updated:

1. `openInBrowser(v)` opens a browser window with a live view of the visualization as it updates. A common practice is to call `openInBrowser` immediately after creating the visualization `v`, and before populating it with traces or doing inference. Then, every `putTrace!` and `deleteTrace!` operation will be animated, providing a live view of the behavior of your inference algorithm.

2. `openInNotebook(v)` is just like `openInBrowser`, but instead opens a live view of the visualization in an IJulia notebook cell's output area. Changes to `v` made in the same cell or in other cells will be reflected in the live view, enabling the same kind of animation as `openInBrowser` without needing another window. *Note, however, that this live view does not survive exporting or saving & reopening the notebook. For that, use `displayInNotebook`.*

3. `saveToFile(v, path)` saves the contents of an *open* visualization `v` to an HTML file with path `path`. Crucially, the visualization _must_ be open somewhere, either in a browser window or a notebook, for this to work. Otherwise, `saveToFile` will block.

4. `displayInNotebook(v)` displays the current state of a visualization `v` in a notebook cell. The displayed visualization is static, and will not be updated when `v` changes. The upside is that unlike `openInNotebook`, the displayed visualization can be saved as part of the notebook, and will persist when the notebook is saved and reopened or exported as HTML.

5. Optionally, `displayInNotebook(v)` can be trailed by a Julia `do` block, e.g.

```julia
displayInNotebook(v) do
    iterative_inference(n_iters=100, viz=v)
end
```
This opens a live display of the visualization `v` and runs the code in the `do` block, animating any changes the code makes to `v`. Then, once the `do` block is over, the live view is "frozen" into a static figure, capturing `v`'s state at the end of the `do` block. The visualization object can still be updated in other notebook cells and re-rendered with another call to `displayInNotebook`. In fact, the same cell can be rerun to further update the visualization and re-freeze it into a static figure.

## Creating a new trace renderer

The easiest way to create a new trace renderer is to modify the provided template, which uses Vue.js behind the scenes. 

First, install [node.js](https://nodejs.org).

Then, copy the `example/vue` directory into your project directory.

The trace renderer is in `vue/src/components/Trace.vue`, and this is the file you should modify. 

The top of the file contains an HTML _template_. In this template, you can access parts of the trace you are rendering with the syntax `trace["address"]`. If the address is hierachical (e.g. `"a" => "b"`), the syntax is `trace["a"]["b"]`. You also have access to a suggested size, in `size.w` and `size.h`: use these, optionally, to make your visualization responsive to resizing. (You may want to use _either_ the suggested width _or_ the suggested height, then maintain whatever aspect ratio makes sense for your rendering.)

Arbitrary comptuation can be used by your template using the `computed` and `methods` objects at the bottom of the `Trace.vue` file.

When you have finished editing the `Trace.vue` file, run:

```
cd vue && npm install && npm run build
```

(The `npm install` is only necessary the first time.)

This should result in a `vue/dist/` directory. Use this directory as the path provided to the `Viz` constructor in the Julia code.
