function [axes1, fig, colors] = plot_surface(beta,lh_annot,rh_annot,min_thresh, max_thresh, colors)

[~, lh_labels, lh_colortable] = read_annotation(lh_annot);
[~, rh_labels, rh_colortable] = read_annotation(rh_annot);

lh_ind = lh_colortable.table(2:length(beta)/2+1,5);
rh_ind = rh_colortable.table(2:length(beta)/2+1,5);

lh_data = zeros(size(lh_labels));
rh_data = zeros(size(rh_labels));


% 遍历每个要突出显示的区域
for i = 1:length(beta)/2
    lh_data(lh_labels == lh_ind(i)) = beta(i);
    rh_data(rh_labels == rh_ind(i)) = beta(length(unique(lh_data))+i-1);
end

lh_data(isnan(lh_data)) = 0; rh_data(isnan(rh_data)) = 0;

valid_ind = sum([length(unique(lh_data)),length(unique(rh_data))])-2;
if nargin==5
    colors = mymap('RdBu');
    colors = colors(end:-1:1, :); % 反转color map，使负数在蓝色，正数在红色
end

% 定义自定义颜色映射
colors = [GenColormap(colors(1:128,:), ceil(valid_ind/2)); GenColormap(colors(129:256,:), ceil(valid_ind/2))];


% 可视化
CBIG_DrawSurfaceMapsWithBoundary_wcw(lh_data, rh_data, lh_labels, rh_labels, ...
    'fsaverage', 'inflated', min_thresh, max_thresh, colors);

all_axes = findobj(gcf, 'Type', 'axes');
axes1 = all_axes([4,5,8,9]);
% axes2 = all_axes([2,3,6,7]);
fig = gcf;


end


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