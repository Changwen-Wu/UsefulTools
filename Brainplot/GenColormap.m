function colormap = GenColormap(map, n)
if nargin < 2
    n = 64;
end
m = size(map, 1);
if m >= n
    colormap = map;
else
    % 范围重置
    range = 0 : m-1;
    range = range*(n-1)/(m-1) + 1;
    % 插值
    colormap = nan(n, 3);
    for i = 1:3
        colormap(:, i) = interp1(range, map(:, i), 1:n);
    end
end
end