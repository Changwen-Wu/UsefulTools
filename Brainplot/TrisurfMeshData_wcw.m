function s = TrisurfMeshData_wcw(mesh, data, parent_axes)

% TrisurfMeshData(mesh, data)

% 如果传入了parent_axes，则在该axes中绘图
if nargin < 3
    figure; % 如果没有指定axes，创建新图形窗口
    parent_axes = gca; % 设置当前axes
end

% 在指定的axes中绘制
s = trisurf(mesh.faces', mesh.vertices(1,:)', mesh.vertices(2,:)', mesh.vertices(3,:)', data, 'Parent', parent_axes);
axis(parent_axes, 'equal');

% shading flat;  % 你可以根据需要设置shading
end
