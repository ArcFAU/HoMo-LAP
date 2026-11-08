function c = carState(T, s)
%HOTLAP.CARSTATE  Car at rest on the centreline at lap distance s (m), pointing along the track.
p = hotlap.poseAt(T, s);
c = struct('x', p.x, 'y', p.y, 'h', p.h, 'vx', 0, 'vy', 0, 'r', 0, 'st', 0, 'thr', 0, 'brk', 0, 'delta', 0, ...
    'axp', 0, 'ayp', 0, 's', 0, 'lat', 0, 'grass', false, 'driftT', 0, 'dLim', 0.4, 'assistBrake', false, ...
    'outT', 0, 'hitWall', false, 'FyfP', 0, 'FyrP', 0);
nr = hotlap.nearestPoint(T, c.x, c.y); c.s = nr.s; c.lat = nr.lat;
end
