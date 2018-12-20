<template>
  <GridViz>
    <div slot-scope="viz">
        <svg :height="viz.size.w" :width="viz.size.w">

            <!-- data points -->
            <circle v-for="n in 199" :key="n" :cx="xLogicalToPixel(viz.info[0][n], viz.size)" 
                :cy="yLogicalToPixel(viz.info[1][n], viz.size)" r="3" :fill="viz.trace['outliers'][n] ? 'red' : 'blue'" />

            <!-- inlier noise -->
            <line :x1="-200" :y1="yLogicalToPixel(xPixelToLogical(-200, viz.size)*viz.trace['slope'] + viz.trace['intercept'], viz.size)" 
                    :x2="700"  :y2="yLogicalToPixel(xPixelToLogical(700, viz.size) *viz.trace['slope'] + viz.trace['intercept'], viz.size)" 
                    :style="'stroke:rgba(0,0,0,0.3);stroke-width:' + stdLogicalToPixel(viz.trace['inlier_std'], viz.size)*2" />

            <!-- outlier noise -->
            <line :x1="-200" :y1="yLogicalToPixel(0., viz.size)" 
                    :x2="700"  :y2="yLogicalToPixel(0., viz.size)" 
                    :style="'stroke:rgba(0,0,0,0.1);stroke-width:' + stdLogicalToPixel(viz.trace['outlier_std'], viz.size)*2" />

            <!-- mean -->
            <line :x1="-200" :y1="yLogicalToPixel(xPixelToLogical(-200, viz.size)*viz.trace['slope'] + viz.trace['intercept'], viz.size)" 
                    :x2="700"  :y2="yLogicalToPixel(xPixelToLogical(700, viz.size) *viz.trace['slope'] + viz.trace['intercept'], viz.size)" 
                    style="stroke:rgba(0,0,0,0.7);stroke-width:2" />
        </svg>
    </div>
  </GridViz>
</template>

<script>
import GridViz from './GridViz.vue'

export default {
  name: 'Regression',
  components: {GridViz},
  methods: {
    xLogicalToPixel(x, sz) {
      return (x + 10) * sz.w/20.0
    },
    yLogicalToPixel(y, sz) {
      return sz.w - ((y + 10) * sz.w/20.0)
    },
    xPixelToLogical(x, sz) {
      return x/(sz.w/20.0) - 10
    }, 
    stdLogicalToPixel(std, sz) {
      return std * sz.w/20.0
    }
  }
}
</script>
