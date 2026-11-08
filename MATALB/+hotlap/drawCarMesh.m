function H = drawCarMesh(ax, car, parent)
%HOTLAP.DRAWCARMESH  Draw the FAUmax tau mesh (data\car_mesh.mat) under an hgtransform.
%   H = hotlap.drawCarMesh(ax, car, parent) returns H.body (patch) and H.wheels (hgtransforms,
%   one per tyre, with fields in H.wheelCentre and H.wheelFront). Coordinates: x forward, y left, z up.
%   If car is empty, draws a simple car from boxes instead.
H.body = []; H.wheels = gobjects(0); H.wheelCentre = zeros(0, 3); H.wheelFront = false(0, 1);
if isempty(car)
    H = primitiveCar(parent, H); return;
end
H.body = patch(ax, 'Parent', parent, 'Faces', car.body.Faces, 'Vertices', double(car.body.Vertices), ...
    'FaceVertexCData', double(car.body.Colors) / 255, 'FaceColor', 'interp', 'EdgeColor', 'none', ...
    'FaceLighting', 'gouraud', 'BackFaceLighting', 'lit', 'AmbientStrength', 0.55, 'DiffuseStrength', 0.7, ...
    'SpecularStrength', 0.35, 'SpecularExponent', 18);
for t = 1:numel(car.tires)
    w = hgtransform('Parent', parent);
    patch(ax, 'Parent', w, 'Faces', car.tires(t).Faces, 'Vertices', double(car.tires(t).Vertices), ...
        'FaceVertexCData', double(car.tires(t).Colors) / 255, 'FaceColor', 'interp', 'EdgeColor', 'none', ...
        'FaceLighting', 'gouraud', 'AmbientStrength', 0.5, 'SpecularStrength', 0.1);
    w.Matrix = makehgtform('translate', double(car.tires(t).centre));
    H.wheels(t) = w; H.wheelCentre(t, :) = double(car.tires(t).centre); H.wheelFront(t) = car.tires(t).front;
end
end

function H = primitiveCar(parent, H)
% fallback when data\car_mesh.mat is missing: red monocoque, carbon wings, four wheels
box = @(c, s, col) patch('Parent', parent, 'Vertices', c + s .* ([0 0 0; 1 0 0; 1 1 0; 0 1 0; 0 0 1; 1 0 1; 1 1 1; 0 1 1] - 0.5), ...
    'Faces', [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8], 'FaceColor', col, 'EdgeColor', 'none', 'FaceLighting', 'flat');
red = [0.84 0.08 0.11]; cf = [0.08 0.09 0.1];
H.body = box([-0.1 0 0.3], [1.9 0.5 0.45], red);
box([0.85 0 0.25], [0.8 0.3 0.25], red); box([1.2 0 0.08], [0.4 1.36 0.03], cf); box([-1.3 0 1.0], [0.3 1.1 0.03], cf);
box([-0.2 0.42 0.24], [0.85 0.3 0.3], red); box([-0.2 -0.42 0.24], [0.85 0.3 0.3], red); box([-0.12 0 0.7], [0.25 0.25 0.25], [1 0.78 0.24]);
c = [0.765 0.62 0.2; 0.765 -0.62 0.2; -0.765 0.6 0.2; -0.765 -0.6 0.2];
for k = 1:4
    w = hgtransform('Parent', parent); w.Matrix = makehgtform('translate', c(k, :));
    patch('Parent', w, 'Vertices', [0 0 0; 1 0 0; 1 1 0; 0 1 0; 0 0 1; 1 0 1; 1 1 1; 0 1 1] - 0.5 .* [1 1 1], 'Faces', [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8], ...
        'FaceColor', [0.07 0.07 0.07], 'EdgeColor', 'none');
    set(w.Children, 'Vertices', w.Children.Vertices .* [0.41 0.19 0.41]);
    H.wheels(k) = w; H.wheelCentre(k, :) = c(k, :); H.wheelFront(k) = c(k, 1) > 0;
end
end
