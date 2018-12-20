# GenViz

## Running the example visualization

```
cd example/
JULIA_PROJECT=. julia run_example.jl
```
The script will print out a URL. Open it in a browser window to view the running visualization.


## Creating a new visualization

Install [node.js](https://nodejs.org).

Copy the `example` directory.

Modify the visualization in `vue/src/components/Trace.vue`.

Modify the Gen source code in `run_example.jl`.

```
cd vue && npm install && npm run build
```
This should result in a `vue/dist/` directory.
