function g = surfaceGrass(T, x, y, mode)
%HOTLAP.SURFACEGRASS  True on grass, false on the paved event area (and the paddock in free roam).
a = T.APRON;
if x > a(1) && x < a(3) && y > a(2) && y < a(4), g = false; return; end
f = T.FREE;
g = ~(strcmp(mode, 'free') && x > f(1) && x < f(3) && y > f(2) && y < f(4));
end
