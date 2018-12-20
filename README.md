# GenViz

## Installation
```
Pkg> add https://github.com/probcomp/GenViz
Pkg> add HTTP#a916dd1219367903f84af56c014c0c2a83ccf694
```

## Running the example visualization

```
cd example/
JULIA_PROJECT=. julia run_example.jl
```
The script will print out a URL. Open it in a browser window to view the running visualization.


## Creating a new visualization

Install [node.js](https://nodejs.org).

Copy the `example` directory.

Modify the visualization in `vue/src/components/Regression.vue` and `vue/src/App.vue`.

Modify the Gen source code in `run_example.jl`.

```
cd vue && npm run build
```
This should result in a `vue/build/` directory.
