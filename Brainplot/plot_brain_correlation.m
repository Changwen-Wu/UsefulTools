function [fig_handle1, fig_handle2, fig_quad] = plot_brain_correlation(xData, yData, varargin)
%   接收两个脑区向量 XDATA 和 YDATA，绘制散点图、X 变量皮层脑图、Y 变量双视角脑图及 Y 变量四视角(2x2)脑图。
%   输出参数:
%      fig_quad - 包含 4 个视角 (第一排: 左外/右外; 第二排: 左内/右内) 的 2x2 脑图图窗句柄

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
addParameter(p, 'CLimY', [], @isnumeric);
addParameter(p, 'color_x_brain', flip(mymap('RdBu')), @isnumeric);
addParameter(p, 'color_y_brain', mymap('inferno'), @isnumeric);
addParameter(p, 'x_limits', [], @isnumeric);
addParameter(p, 'y_limits', [], @isnumeric);
addParameter(p, 'pic_width', 8, @(x) isnumeric(x) && isscalar(x));

parse(p, xData, yData, varargin{:});
opts = p.Results;
opts.pic_height = opts.pic_width*11/8.5;
xData = xData(:);
yData = yData(:);

scale_factor = opts.pic_width / 8.5;

% 所有视觉样式参数均挂钩 scale_factor
font_label = 9 * scale_factor;      % 轴标签与 Title 字号
font_tick  = 7.5 * scale_factor;    % 刻度与 Colorbar 数字字号
line_width = 0.8 * scale_factor;    % 坐标轴与线条宽度

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
if isempty(opts.CLimY), opts.CLimY = [min(yData), max(yData)]; end

% --- 图窗画布参数设置 ---
fig_handle1 = figure('Color', 'w', ...
    'Units', 'centimeters', 'Position', [2, 2, opts.pic_width, opts.pic_height], ...
    'PaperUnits', 'centimeters', 'PaperSize', [opts.pic_width, opts.pic_height], ...
    'PaperPosition', [0, 0, opts.pic_width, opts.pic_height]);

% --- 组件尺寸与位置全局挂钩算式 ---
% 散点图尺寸 (基准下 X 轴长 6 cm，高度比例联动)
scatter_w      = 6.0 * scale_factor; 
scatter_h      = 6.0 * (opts.pic_height / 11.0); % 高度按高度比例缩放
scatter_left   = 2.2 * scale_factor; 
scatter_bottom = 4.2 * (opts.pic_height / 11.0);  

brain_w = 2.6 * scale_factor; 
brain_h = brain_w * 1.35;

% 1. 散点图绘制与定位
[~, axes_scatter] = scatter_plot(xData, yData, opts.CorrType, {opts.xName, opts.yName}, ...
    'pVal', final_p, 'x_limits', opts.x_limits, 'y_limits', opts.y_limits, ...
    'font_label', font_label, 'font_tick', font_tick, 'line_width', line_width);

new_axes = copyobj(axes_scatter, fig_handle1);
set(new_axes, 'Units', 'centimeters', 'Position', [scatter_left, scatter_bottom, scatter_w, scatter_h]);

% 2. X 轴脑图定位 (相对位置按比例联动)
scatter_center_x = scatter_left + scatter_w / 2;
x_brain_y        = scatter_bottom - brain_h - (0 * scale_factor);

[handles_x, fig_x, colors_x] = plot_surface(xData, opts.AnnotLH, opts.AnnotRH, opts.CLimX(1), opts.CLimX(2), opts.color_x_brain);

ax_x1 = copyobj(handles_x(4), fig_handle1);
set(ax_x1, 'Units', 'centimeters', ...
    'Position', [scatter_center_x - brain_w - (0.1 * scale_factor), x_brain_y, brain_w, brain_h]);

ax_x2 = copyobj(handles_x(2), fig_handle1);
set(ax_x2, 'Units', 'centimeters', ...
    'Position', [scatter_center_x + (0.1 * scale_factor), x_brain_y, brain_w, brain_h]);

cbar_x_w = brain_w * 0.5;
add_horizontal_colorbar(fig_handle1, colors_x, opts.CLimX, ...
    scatter_center_x - cbar_x_w/2, x_brain_y + (0.7 * scale_factor), cbar_x_w, 0.2 * scale_factor, opts.X_bar_name, font_tick);

if isvalid(fig_x), delete(fig_x); end
if isvalid(axes_scatter), delete(axes_scatter); end

% 3. 生成单独的 Y 变量脑图 (双视角)
fig_handle2 = plot_single_brain_map(yData, opts.Y_bar_name, opts.AnnotLH, opts.AnnotRH, opts.color_y_brain, ...
    'Clim', opts.CLimY, 'scale_factor', scale_factor);

% 4. 生成单独的 Y 变量脑图 (四视角 2x2: 第一排 左外/右外，第二排 左内/右内)
fig_quad = plot_quad_brain_map(yData, opts.Y_bar_name, opts.AnnotLH, opts.AnnotRH, opts.color_y_brain, ...
    'Clim', opts.CLimY, 'scale_factor', scale_factor);

end


%% ===== 双脑图绘制函数 (挂钩 scale_factor) =====
function fig_single = plot_single_brain_map(brainData, labelName, AnnotLH, AnnotRH, color_y_brain, varargin)
p = inputParser;
addRequired(p, 'brainData', @isnumeric);
addRequired(p, 'labelName', @ischar);
addParameter(p, 'CLim', [], @isnumeric);
addParameter(p, 'scale_factor', 1.0, @isnumeric);

parse(p, brainData, labelName, varargin{:});
opts = p.Results;

sf = opts.scale_factor;
font_tick = 7.5 * sf;

brainData = brainData(:);
if isempty(opts.CLim), opts.CLim = [min(brainData), max(brainData)]; end

fig_w = 7.0 * sf; 
fig_h = 5.0 * sf;

fig_single = figure('Color', 'w', ...
    'Units', 'centimeters', 'Position', [2, 2, fig_w, fig_h], ...
    'PaperUnits', 'centimeters', 'PaperSize', [fig_w, fig_h], ...
    'PaperPosition', [0, 0, fig_w, fig_h]);

brain_w = 2.6 * sf; 
brain_h = brain_w * 1.35;
center_x = fig_w / 2;
brain_y = 1.2 * sf;

[handles_y, fig_temp, colors_y] = plot_surface(brainData, AnnotLH, AnnotRH, opts.CLim(1), opts.CLim(2), color_y_brain);

ax_y1 = copyobj(handles_y(4), fig_single);
set(ax_y1, 'Units', 'centimeters', 'Position', [center_x - brain_w - (0.1 * sf), brain_y, brain_w, brain_h]);

ax_y2 = copyobj(handles_y(2), fig_single);
set(ax_y2, 'Units', 'centimeters', 'Position', [center_x + (0.1 * sf), brain_y, brain_w, brain_h]);

cbar_w = brain_w * 0.5;
add_horizontal_colorbar(fig_single, colors_y, opts.CLim, ...
    center_x - cbar_w/2, brain_y + (0.7 * sf), cbar_w, 0.2 * sf, labelName, font_tick);

if isvalid(fig_temp), delete(fig_temp); end
end


%% ===== 四脑图绘制函数 (2x2 排列: 第一排左外/右外，第二排左内/右内) =====
function fig_quad = plot_quad_brain_map(brainData, labelName, AnnotLH, AnnotRH, color_y_brain, varargin)
p = inputParser;
addRequired(p, 'brainData', @isnumeric);
addRequired(p, 'labelName', @ischar);
addParameter(p, 'CLim', [], @isnumeric);
addParameter(p, 'scale_factor', 1.0, @isnumeric);

parse(p, brainData, labelName, varargin{:});
opts = p.Results;

sf = opts.scale_factor;
font_tick = 7.5 * sf;

brainData = brainData(:);
if isempty(opts.CLim), opts.CLim = [min(brainData), max(brainData)]; end

% 适配 2x2 排列的画布高宽
fig_w = 7.0 * sf; 
fig_h = 8.0 * sf;

fig_quad = figure('Color', 'w', ...
    'Units', 'centimeters', 'Position', [2, 2, fig_w, fig_h], ...
    'PaperUnits', 'centimeters', 'PaperSize', [fig_w, fig_h], ...
    'PaperPosition', [0, 0, fig_w, fig_h]);

brain_w = 2.6 * sf; 
brain_h = brain_w * 1.35;
spacing_x = 0.1 * sf;
spacing_y = 0.1 * sf;

center_x = fig_w / 2;

% 计算两排脑图的 y 轴坐标
% 第二排（下层: 左内, 右内）y 位置
row2_y = 1.2 * sf; 
% 第一排（上层: 左外, 右外）y 位置
row1_y = row2_y + brain_h*0.55;

% plot_surface 返回句柄映射顺序: 1:LH_med, 2:RH_lat, 3:RH_med, 4:LH_lat
[handles_y, fig_temp, colors_y] = plot_surface(brainData, AnnotLH, AnnotRH, opts.CLim(1), opts.CLim(2), color_y_brain);

% --- 第一排：左外 (LH_lat: 4) , 右外 (RH_lat: 2) ---
ax_r1_c1 = copyobj(handles_y(4), fig_quad);
set(ax_r1_c1, 'Units', 'centimeters', 'Position', [center_x - brain_w - spacing_x, row1_y, brain_w, brain_h]);

ax_r1_c2 = copyobj(handles_y(2), fig_quad);
set(ax_r1_c2, 'Units', 'centimeters', 'Position', [center_x + spacing_x, row1_y, brain_w, brain_h]);

% --- 第二排：左内 (LH_med: 1) , 右内 (RH_med: 3) ---
ax_r2_c1 = copyobj(handles_y(1), fig_quad);
set(ax_r2_c1, 'Units', 'centimeters', 'Position', [center_x - brain_w - spacing_x, row2_y, brain_w, brain_h]);

ax_r2_c2 = copyobj(handles_y(3), fig_quad);
set(ax_r2_c2, 'Units', 'centimeters', 'Position', [center_x + spacing_x, row2_y, brain_w, brain_h]);

% Colorbar 居中放置在第二排下侧
cbar_w = brain_w * 0.6;
add_horizontal_colorbar(fig_quad, colors_y, opts.CLim, ...
    center_x - cbar_w/2, row2_y + (0.7 * sf), cbar_w, 0.2 * sf, labelName, font_tick);

if isvalid(fig_temp), delete(fig_temp); end
end


%% ===== Colorbar 绘制辅助函数 =====
function add_horizontal_colorbar(parent_fig, colors, c_limits, pos_x, pos_y, width, height, label_title, font_tick)
    cbar_axes = axes('Parent', parent_fig, 'Units', 'centimeters', 'Position', [0, 0, 1, 1], 'Visible', 'off');
    colors([1, end], :) = []; 
    colormap(cbar_axes, colors);
    
    c = colorbar(cbar_axes, 'Units', 'centimeters', 'Position', [pos_x, pos_y, width, height], ...
        'Orientation', 'horizontal');
    set(c, 'Ticks', [], 'TickLabels', {});
    clim(cbar_axes, c_limits);
    
    % 数字放在 Bar 两端
    if and((c_limits(2)-c_limits(1)) > 0.1, ((c_limits(2)-c_limits(1))<10))
        str_min = sprintf('%.2f', c_limits(1));
        str_max = sprintf('%.2f', c_limits(2));
    elseif (c_limits(2)-c_limits(1))>10
        str_min = sprintf('%.1f', c_limits(1));
        str_max = sprintf('%.1f', c_limits(2));
    else
        str_min = sprintf('%.3f', c_limits(1));
        str_max = sprintf('%.3f', c_limits(2));
    end
    
    % 文本偏移量随字体大小动态微调
    offset_x = width * 0.05;
    offset_y = height * 0.5;
    
    text(cbar_axes, pos_x - 0.7*offset_x, pos_y + height/2, str_min, 'FontName', 'Arial', 'FontSize', font_tick, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'Units', 'centimeters');
    text(cbar_axes, pos_x + width + offset_x*1.2, pos_y + height/2, str_max, 'FontName', 'Arial', 'FontSize', font_tick, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Units', 'centimeters');
    % 名称放在 Bar 正下方
    text(cbar_axes, pos_x + width/2, pos_y - height - offset_y, label_title, 'FontName', 'Arial', 'FontSize', font_tick, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Units', 'centimeters');
end


%% ===== 散点图绘制辅助函数 =====
function [figureHandle, axesHandle] = scatter_plot(xData, yData, correlationType, Scatter_label, varargin)
p_parser = inputParser;
addRequired(p_parser, 'xData', @isnumeric);
addRequired(p_parser, 'yData', @isnumeric);
addRequired(p_parser, 'correlationType', @ischar);
addRequired(p_parser, 'Scatter_label', @(x) iscell(x) || ischar(x));
addParameter(p_parser, 'pVal', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p_parser, 'SpinMat', '', @ischar);
addParameter(p_parser, 'UseSpin', false, @islogical);
addParameter(p_parser, 'x_limits', [], @isnumeric);
addParameter(p_parser, 'y_limits', [], @isnumeric);
addParameter(p_parser, 'font_label', 9, @isnumeric);
addParameter(p_parser, 'font_tick', 7.5, @isnumeric);
addParameter(p_parser, 'line_width', 0.8, @isnumeric);

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
    perm_id = spin_data.perm_id;
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

figureHandle = figure('Color', 'w', 'Units', 'centimeters');
axesHandle = axes('Parent', figureHandle);

fill(axesHandle, [fitX; flipud(fitX)], ...
    [predictedY - predInterval; flipud(predictedY + predInterval)], ...
    [231 231 231] / 255, 'FaceAlpha', 0.8, 'EdgeColor', 'none');
hold(axesHandle, 'on');

% 散点 Marker 大小也随 linewidth 适度联动
scatter(axesHandle, sortedX, sortedY, 20 * (opts.line_width/0.8)^2, 'filled', ...
    'MarkerFaceColor', [147 187 219] / 255, ...
    'MarkerEdgeColor', [89 93 161] / 255, ...
    'LineWidth', opts.line_width * 0.8);

plot(axesHandle, fitX, predictedY, 'Color', [204 69 72] / 255, 'LineWidth', opts.line_width * 2);

if p < 0.001
    title_str = sprintf('%s = %.3f, {\\itp} < 0.001', stat_symbol, r);
else
    title_str = sprintf('%s = %.3f, {\\itp} = %.3f', stat_symbol, r, p);
end

title(axesHandle, title_str, 'FontName', 'Arial', 'FontSize', opts.font_label, ...
    'FontWeight', 'normal', 'Interpreter', 'tex');

if iscell(Scatter_label)
    xlabel(axesHandle, Scatter_label{1}, 'FontName', 'Arial', 'FontSize', opts.font_label);
    ylabel(axesHandle, Scatter_label{2}, 'FontName', 'Arial', 'FontSize', opts.font_label);
end

% 坐标轴范围计算
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
    'FontSize', opts.font_tick, ...
    'LineWidth', opts.line_width, ...
    'TickDir', 'out', ...
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