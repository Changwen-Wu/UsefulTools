function [fig_handle1, fig_handle2] = plot_brain_correlation(xData, yData, varargin)
%   接收两个脑区向量 XDATA 和 YDATA，绘制散点图、X 变量皮层脑图及 Y 变量单脑图。
%
%   ========================================================================
%   输入参数 (Required Input Arguments):
%   ========================================================================
%     xData      - 脑区数据向量 X (N x 1 或 1 x N 向量, N 为脑区数量)
%     yData      - 脑区数据向量 Y (N x 1 或 1 x N 向量)
%
%   ========================================================================
%   可选参数 (Optional Name-Value Pair Parameters):
%   ========================================================================
%     'xName'       - 散点图 X 轴标签名称 (字符型, 默认: 'Variable X')。
%                     *注: 若 CorrType='Spearman'，函数会自动前置 'Rank of xxx'
%     'yName'       - 散点图 Y 轴标签名称 (字符型, 默认: 'Variable Y')
%
%     'X_bar_name'  - X 脑图 Colorbar 上方显示的统计量/变量名称 (字符型, 默认: 'Variable X')
%     'Y_bar_name'  - Y 脑图 Colorbar 上方显示的统计量/变量名称 (字符型, 默认: 'Variable Y')
%
%     'CorrType'    - 相关分析类型 ('Spearman' 或 'Pearson', 默认: 'Spearman')。
%                     *若为 Spearman，散点图会自动转换为秩次 (tiedrank) 空间拟合。
%
%     'pVal'        - 手动指定的统计 p 值 (标量, 默认: []，若提供则优先使用此值)。
%
%     'UseSpin'     - 是否使用空间旋转置换检验 (Spin Test) 计算 p 值 (逻辑型, 默认: true)。
%     'SpinMat'     - 空间旋转置换矩阵文件路径 (字符型)。
%                     *内部需包含 perm_id 旋转索引矩阵 (N x Num_Rotations)。
%
%     'AnnotLH'     - 左脑 Freesurfer 注释/图谱文件路径 (字符型)
%     'AnnotRH'     - 右脑 Freesurfer 注释/图谱文件路径 (字符型)
%
%     'CLimX'       - X 脑图色彩映射上下限 [min, max] (数值向量, 默认: [min(xData), max(xData)])。
%
%     'color_x_brain'- X 脑图映射调色板 (K x 3 RGB 矩阵, 默认: flip(mymap('RdBu')))。
%     'color_y_brain'- Y 脑图映射调色板 (K x 3 RGB 矩阵, 默认: mymap('inferno'))。
%
%     'x_limits'    - 散点图 X 轴显示坐标范围 [xmin, xmax] (数值向量, 默认: [] 自适应)。
%     'y_limits'    - 散点图 Y 轴显示坐标范围 [ymin, ymax] (数值向量, 默认: [] 自适应)。
%
%   ========================================================================
%   输出参数 (Output Arguments):
%   ========================================================================
%     fig_handle1  - 组合图窗句柄，包含散点拟合图与 X 变量脑图及 Colorbar。
%     fig_handle2  - 单独 Y 变量脑图及 Colorbar 的图窗句柄。

p = inputParser;
addRequired(p, 'xData', @isnumeric);
addRequired(p, 'yData', @isnumeric);
addParameter(p, 'xName', 'Variable X', @ischar);
addParameter(p, 'yName', 'Variable Y', @ischar);
addParameter(p, 'X_bar_name', 'Variable X', @ischar);
addParameter(p, 'Y_bar_name', 'Variable Y', @ischar);
addParameter(p, 'CorrType', 'Spearman', @ischar);
addParameter(p, 'pVal', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'UseSpin', true, @islogical);
addParameter(p, 'SpinMat', '', @ischar);
addParameter(p, 'AnnotLH', '', @ischar);
addParameter(p, 'AnnotRH', '', @ischar);
addParameter(p, 'CLimX', [], @isnumeric);
addParameter(p, 'color_x_brain', flip(mymap('RdBu')), @isnumeric);
addParameter(p, 'color_y_brain', mymap('inferno'), @isnumeric);
addParameter(p, 'x_limits', [], @isnumeric);
addParameter(p, 'y_limits', [], @isnumeric);

parse(p, xData, yData, varargin{:});
opts = p.Results;
xData = xData(:);
yData = yData(:);

% p 值获取
if ~isempty(opts.pVal)
    final_p = opts.pVal;
elseif opts.UseSpin && isfile(opts.SpinMat)
    spin_data = load(opts.SpinMat);
    perm_id = spin_data.perm_id;
    [final_p, ~] = perm_sphere_p_wcw(xData, yData, perm_id, lower(opts.CorrType));
else
    [~, final_p] = corr(xData, yData, 'Type', opts.CorrType);
end

if isempty(opts.CLimX), opts.CLimX = [min(xData), max(xData)]; end

% 画布参数
pic_width = 600;
pic_height = 650;
fig_handle1 = figure('Position', [200, 100, pic_width, pic_height], 'Color', 'w');

scatter_w = 320; scatter_h = 320;
scatter_left = 180; scatter_bottom = 240;  
brain_w = 110; brain_h = brain_w * 1.35;

% 1. 散点图
[~, axes_scatter] = scatter_plot(xData, yData, opts.CorrType, {opts.xName, opts.yName}, ...
    'pVal', final_p, 'x_limits', opts.x_limits, 'y_limits', opts.y_limits);
new_axes = copyobj(axes_scatter, fig_handle1);
set(new_axes, 'Units', 'pixels', 'Position', [scatter_left, scatter_bottom, scatter_w, scatter_h]);

% 2. X 轴脑图 (向上靠近散点图 X 轴)
scatter_center_x = scatter_left + scatter_w / 2;
x_brain_y = scatter_bottom - brain_h - 15;

[handles_x, fig_x, colors_x] = plot_surface(xData, opts.AnnotLH, opts.AnnotRH, opts.CLimX(1), opts.CLimX(2), opts.color_x_brain);

ax_x1 = copyobj(handles_x(4), fig_handle1);
set(ax_x1, 'Units', 'pixels', 'Position', [scatter_center_x - brain_w - 5, x_brain_y, brain_w, brain_h]);

ax_x2 = copyobj(handles_x(2), fig_handle1);
set(ax_x2, 'Units', 'pixels', 'Position', [scatter_center_x + 5, x_brain_y, brain_w, brain_h]);

cbar_x_w = brain_w * 0.65; 
add_horizontal_colorbar(fig_handle1, colors_x, opts.CLimX, ...
    scatter_center_x - cbar_x_w/2, x_brain_y + 20, cbar_x_w, 8, opts.X_bar_name);

if isvalid(fig_x), delete(fig_x); end
if isvalid(axes_scatter), delete(axes_scatter); end

fig_handle2 = plot_single_brain_map(yData, opts.Y_bar_name, opts.AnnotLH, opts.AnnotRH, opts.color_y_brain);

end

function fig_single = plot_single_brain_map(brainData, labelName, AnnotLH, AnnotRH, color_y_brain, varargin)
p = inputParser;
addRequired(p, 'brainData', @isnumeric);
addRequired(p, 'labelName', @ischar);
addParameter(p, 'CLim', [], @isnumeric);

parse(p, brainData, labelName, varargin{:});
opts = p.Results;

brainData = brainData(:);
if isempty(opts.CLim), opts.CLim = [min(brainData), max(brainData)]; end

fig_w = 400; fig_h = 280;
fig_single = figure('Position', [100, 100, fig_w, fig_h], 'Color', 'w');

brain_w = 110; brain_h = brain_w * 1.35;
center_x = fig_w / 2;
brain_y = 80;

[handles_y, fig_temp, colors_y] = plot_surface(brainData, AnnotLH, AnnotRH, opts.CLim(1), opts.CLim(2), color_y_brain);

ax_y1 = copyobj(handles_y(4), fig_single);
set(ax_y1, 'Units', 'pixels', 'Position', [center_x - brain_w - 5, brain_y, brain_w, brain_h]);

ax_y2 = copyobj(handles_y(2), fig_single);
set(ax_y2, 'Units', 'pixels', 'Position', [center_x + 5, brain_y, brain_w, brain_h]);

cbar_w = brain_w * 0.65;
add_horizontal_colorbar(fig_single, colors_y, opts.CLim, ...
    center_x - cbar_w/2, brain_y + 20, cbar_w, 8, labelName);

if isvalid(fig_temp), delete(fig_temp); end
end


%% ===== Colorbar 绘制辅助函数 =====
function add_horizontal_colorbar(parent_fig, colors, c_limits, pos_x, pos_y, width, height, label_title)
    cbar_axes = axes('Position', [0, 0, 1, 1], 'Visible', 'off', 'Parent', parent_fig);
    colors([1, end], :) = []; 
    colormap(cbar_axes, colors);
    
    c = colorbar(cbar_axes, 'Units', 'pixels', 'Position', [pos_x, pos_y, width, height], ...
        'Orientation', 'horizontal');
    set(c, 'Ticks', [], 'TickLabels', {});
    clim(c_limits);
    
    % 数字放在 Bar 两端
    text(pos_x - 5, pos_y + height/2, num2str(c_limits(1), '%.2f'), 'FontName', 'Arial', 'FontSize', 8, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'Parent', cbar_axes, 'Units', 'pixels');
    text(pos_x + width + 5, pos_y + height/2, num2str(c_limits(2), '%.2f'), 'FontName', 'Arial', 'FontSize', 8, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Parent', cbar_axes, 'Units', 'pixels');
    
    % 名称放在 Bar 正上方 (pos_y + height)
    text(pos_x + width/2, pos_y + height, label_title, 'FontName', 'Arial', 'FontSize', 7, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Parent', cbar_axes, 'Units', 'pixels');
end


%% ===== 散点图绘制辅助函数 =====
function [figureHandle, axesHandle] = scatter_plot(xData, yData, correlationType, Scatter_label, varargin)
p_parser = inputParser;
addRequired(p_parser, 'xData', @isnumeric);
addRequired(p_parser, 'yData', @isnumeric);
addRequired(p_parser, 'correlationType', @ischar);
addRequired(p_parser, 'Scatter_label', @(x) iscell(x) || ischar(x));
addParameter(p_parser, 'pVal', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p_parser, 'SpinMat', 'Data\Spin_rotation\Schaefer400_rotation.mat', @ischar);
addParameter(p_parser, 'UseSpin', false, @islogical);
addParameter(p_parser, 'x_limits', [], @isnumeric);
addParameter(p_parser, 'y_limits', [], @isnumeric);

parse(p_parser, xData, yData, correlationType, Scatter_label, varargin{:});
opts = p_parser.Results;

xData = xData(:);
yData = yData(:);
valid_idx = ~isnan(xData) & ~isnan(yData);
xData = xData(valid_idx);
yData = yData(valid_idx);

[r, ~] = corr(xData, yData, 'Type', correlationType, 'Rows', 'pairwise');
if ~isempty(opts.pVal)
    p = opts.pVal;
elseif opts.UseSpin && isfile(opts.SpinMat)
    spin_data = load(opts.SpinMat);
    if isfield(spin_data, 'perm_id')
        perm_id = spin_data.perm_id;
    else
        perm_id = struct2array(spin_data);
    end
    p = perm_sphere_p_wcw(xData, yData, perm_id, correlationType);
else
    [~, p] = corr(xData, yData, 'Type', correlationType);
end

% Spearman 转换
if strcmpi(correlationType, 'Spearman')
    plotX = tiedrank(xData);
    plotY = tiedrank(yData);
    stat_symbol = '{\itrho}';
    
    if iscell(Scatter_label)
        if ~contains(Scatter_label{1}, 'Rank of', 'IgnoreCase', true)
            Scatter_label{1} = ['Rank of ', Scatter_label{1}];
        end
        if ~contains(Scatter_label{2}, 'Rank of', 'IgnoreCase', true)
            Scatter_label{2} = ['Rank of ', Scatter_label{2}];
        end
    end
else
    plotX = xData;
    plotY = yData;
    stat_symbol = '{\itr}';
end

[sortedX, sortIdx] = sort(plotX);
sortedY = plotY(sortIdx);

[polyCoeff, fitStats] = polyfit(sortedX, sortedY, 1);
fitX = linspace(min(sortedX), max(sortedX), 200)';
[predictedY, predInterval] = polyconf(polyCoeff, fitX, fitStats, 'predopt', 'curve');

figureHandle = figure('Color', 'w');
axesHandle = axes('Parent', figureHandle);

fill(axesHandle, [fitX; flipud(fitX)], ...
    [predictedY - predInterval; flipud(predictedY + predInterval)], ...
    [231 231 231] / 255, 'FaceAlpha', 0.8, 'EdgeColor', 'none');
hold(axesHandle, 'on');

scatter(axesHandle, sortedX, sortedY, 25, 'filled', ...
    'MarkerFaceColor', [71 150 200] / 255, ...
    'MarkerEdgeColor', 'w', ...
    'LineWidth', 0.5);

plot(axesHandle, fitX, predictedY, 'Color', [239 109 33] / 255, 'LineWidth', 2);

if p < 0.001
    title_str = sprintf('%s = %.3f, {\\itp} < 0.001', stat_symbol, r);
else
    title_str = sprintf('%s = %.3f, {\\itp} = %.3f', stat_symbol, r, p);
end

% 加上 'Interpreter', 'tex' 就能正常渲染出斜体希腊字母 ρ 和斜体 p
title(axesHandle, title_str, 'FontName', 'Arial', 'FontSize', 11, 'FontWeight', 'normal', 'Interpreter', 'tex');

if iscell(Scatter_label)
    xlabel(axesHandle, Scatter_label{1}, 'FontName', 'Arial', 'FontSize', 11);
    ylabel(axesHandle, Scatter_label{2}, 'FontName', 'Arial', 'FontSize', 11);
end

% 计算 Limit：Spearman 取 [min, max]
if isempty(opts.x_limits)
    if strcmpi(correlationType, 'Spearman')
        x_limits = [min(sortedX)-1, max(sortedX)];

    else
        x_range = max(sortedX) - min(sortedX);
        x_limits = [min(sortedX) - 0.08 * x_range, max(sortedX) + 0.08 * x_range];
    end
else
    x_limits = opts.x_limits;
end

if isempty(opts.y_limits)
    if strcmpi(correlationType, 'Spearman')
        y_limits = [min(sortedY)-1, max(sortedY)];
    else
        y_range = max(sortedY) - min(sortedY);
        y_limits = [min(sortedY) - 0.08 * y_range, max(sortedY) + 0.08 * y_range];
    end
else
    y_limits = opts.y_limits;
end



set(axesHandle, ...
    'XLim', x_limits, ...
    'YLim', y_limits, ...
    'XTick', linspace(x_limits(1), x_limits(2), 6), ...
    'YTick', linspace(y_limits(1), y_limits(2), 6), ...
    'FontName', 'Arial', ...
    'FontSize', 10, ...
    'LineWidth', 1, ...
    'TickDir', 'none', ...
    'Box', 'off');


if strcmpi(correlationType, 'Spearman')
    xtickformat(axesHandle, '%d');
    ytickformat(axesHandle, '%d');
else
    xtickformat(axesHandle, '%.2f');
    ytickformat(axesHandle, '%.2f');
end

grid(axesHandle, 'off');
hold(axesHandle, 'off');
end