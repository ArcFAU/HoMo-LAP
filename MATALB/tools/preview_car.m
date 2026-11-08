function preview_car(outFile)
%PREVIEW_CAR  Render data\car_mesh.mat from the left, right, rear and front (livery check).
%   preview_car() shows a figure; preview_car(file) also saves it as an image.
root = fileparts(fileparts(mfilename('fullpath')));
car = load(fullfile(root, 'data', 'car_mesh.mat'));
fig = figure('Color', [0.73 0.83 0.92], 'Position', [80 80 1400 800], 'Visible', ~nargin);
views = {'Left side', [0 1 0.15]; 'Right side', [0 -1 0.15]; 'Rear', [-1 0 0.25]; 'Front three-quarter', [1 0.8 0.5]};
for k = 1:4
    ax = subplot(2, 2, k, 'Parent', fig);
    hotlap.drawCarMesh(ax, car, hgtransform('Parent', ax));
    axis(ax, 'equal', 'off'); camproj(ax, 'perspective');
    d = views{k, 2}; campos(ax, 6 * d / norm(d) + [0 0 0.45]); camtarget(ax, [0 0 0.45]); camva(ax, 26);
    light(ax, 'Position', [1 0.6 1], 'Style', 'infinite'); light(ax, 'Position', [-1 -0.6 0.5], 'Style', 'infinite', 'Color', [0.45 0.45 0.45]);
    title(ax, views{k, 1});
end
if nargin, exportgraphics(fig, outFile, 'Resolution', 110); close(fig); end
end
