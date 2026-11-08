function p = poseAt(T, s)
%HOTLAP.POSEAT  Position and heading on the centreline at lap distance s (m).
%   Code-generation compatible.
s = mod(s, T.LEN);
lo = 1; hi = T.N + 1;
while hi - lo > 1
    m = floor((lo + hi) / 2);
    if T.S(m) <= s, lo = m; else, hi = m; end
end
f = (s - T.S(lo)) / T.SEG(lo); j = lo + 1; if j > T.N, j = 1; end
p = struct('x', T.x(lo) + (T.x(j) - T.x(lo)) * f, 'y', T.y(lo) + (T.y(j) - T.y(lo)) * f, 'h', atan2(T.TTY(lo), T.TTX(lo)));
end
