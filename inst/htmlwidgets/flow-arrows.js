function(el, x, data) {
  var map = this;
  var flows = {};
  var arrows = {};

  function flatLatLngs(layer) {
    var coords = layer.getLatLngs();
    while (coords.length && Array.isArray(coords[0])) coords = coords[0];
    return coords;
  }

  // Match layers by package-owned classes, including repeated flow pairs.
  map.eachLayer(function(layer) {
    if (typeof layer.getLatLngs !== 'function') return;
    var name = layer.options.className || '';
    var match = /donutmap-(flow|arrow)-(\d+)/.exec(name);
    if (!match) return;
    if (match[1] === 'flow') {
      flows[match[2]] = {layer: layer, original: flatLatLngs(layer).slice()};
    } else {
      arrows[match[2]] = {layer: layer, tip: flatLatLngs(layer)[0]};
    }
  });

  function positionAt(points, distances, distance) {
    var last = points.length - 1;
    for (var i = 1; i <= last; i++) {
      if (distances[i] >= distance && distances[i] > distances[i - 1]) {
        var t = (distance - distances[i - 1]) / (distances[i] - distances[i - 1]);
        return points[i - 1].add(points[i].subtract(points[i - 1]).multiplyBy(t));
      }
    }
    return points[last];
  }

  function redraw() {
    Object.keys(arrows).forEach(function(id) {
      if (!flows[id]) return;
      var flow = flows[id];
      var arrow = arrows[id];
      var points = flow.original.map(function(p) { return map.latLngToLayerPoint(p); });
      var target = map.latLngToLayerPoint(arrow.tip);
      var distances = [0];
      var best = Infinity;
      var tipDistance = 0;

      // Locate the tip on the displayed curve, then walk back by a pixel length.
      for (var i = 1; i < points.length; i++) {
        var delta = points[i].subtract(points[i - 1]);
        var length = points[i].distanceTo(points[i - 1]);
        distances[i] = distances[i - 1] + length;
        if (length === 0) continue;
        var relative = target.subtract(points[i - 1]);
        var t = Math.max(0, Math.min(1,
          (relative.x * delta.x + relative.y * delta.y) / (length * length)));
        var candidate = points[i - 1].add(delta.multiplyBy(t));
        var error = candidate.distanceTo(target);
        if (error < best) {
          best = error;
          tipDistance = distances[i - 1] + t * length;
        }
      }
      var total = distances[distances.length - 1];
      if (!(total > 0 && tipDistance > 0)) return;
      var size = Math.min(data.size, total * 0.25, tipDistance * 0.5);
      var baseDistance = tipDistance - size;
      var base = positionAt(points, distances, baseDistance);
      var tip = positionAt(points, distances, tipDistance);
      var direction = tip.subtract(base);
      var chord = tip.distanceTo(base);
      if (!(chord > 0)) return;
      var halfWidth = Math.min(Math.max(size * 0.7, flow.layer.options.weight * 1.8),
        size * 1.2) / 2;
      var perpendicular = L.point(-direction.y / chord, direction.x / chord);
      var left = base.add(perpendicular.multiplyBy(halfWidth));
      var right = base.subtract(perpendicular.multiplyBy(halfWidth));
      var stem = points.filter(function(p, index) { return distances[index] < baseDistance; });
      stem.push(base);
      flow.layer.setLatLngs(stem.map(function(p) { return map.layerPointToLatLng(p); }));
      arrow.layer.setLatLngs([tip, left, right].map(function(p) {
        return map.layerPointToLatLng(p);
      }));
    });
  }

  map.on('zoomend resize', redraw);
  redraw();
}
