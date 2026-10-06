function(el, options) {
  // Keep fractional pixels for this map using public Leaflet projection methods.
  // The ordinary map origin, tiles and Leaflet's global classes are unchanged.
  var PreciseMap = L.Map.extend({
    latLngToLayerPoint: function(latlng) {
      return this.project(L.latLng(latlng)).subtract(this.getPixelOrigin());
    }
  });
  return new PreciseMap(el, options);
}
