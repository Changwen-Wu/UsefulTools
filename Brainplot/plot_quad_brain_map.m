function fig_quad = plot_quad_brain_map(brainData, labelName, AnnotLH, AnnotRH, color_y_brain, varargin)
% PLOT_QUAD_BRAIN_MAP Plot one regional vector in four cortical views.
% Extracted from plot_brain_correlation.m, including its colorbar helper.
% Top row: left/right lateral; bottom row: left/right medial.
%
% fig_quad = plot_quad_brain_map(brainData, labelName, AnnotLH, AnnotRH, ...
%     colors, 'CLim', [minimum maximum], 'scale_factor', 1.0)
%
% brainData: parcel values in the order expected by plot_surface.
% labelName: colorbar label; AnnotLH/AnnotRH: annotation file paths.
% colors: RGB colormap (for example, mymap('RdYlGn')).
% CLim: color limits; defaults to the data minimum and maximum.
% scale_factor: multiply the original layout dimensions and font sizes.
% Requires the same toolbox paths and FreeSurfer assets as plot_surface.
% See example/example_quad.m for an independent runnable example.
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
