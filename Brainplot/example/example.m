% Resolve toolbox, annotation and output paths from this script.
% Requires the FreeSurfer fsaverage lh.cortex.label and rh.cortex.label files
% under Brainplot/Parcellations/FreeSurfer5.3/fsaverage/label/.
example_dir = fileparts(mfilename('fullpath'));
brainplot_dir = fileparts(example_dir);
addpath(brainplot_dir, fullfile(brainplot_dir, 'BasicTools'), ...
    fullfile(brainplot_dir, 'surf'), example_dir);

% Synthetic demonstration data; use the ordinary correlation p-value.
% For real cortical maps, supply a validated spin-test p-value or SpinMat.
rng(0, 'twister');
x_data = rand(1,200);
y_data = rand(1,200);
xName = 'testx';
yName = 'testy';

[fig_handle1, fig_handle2, fig_quad] = plot_brain_correlation(x_data, y_data, ...
    'AnnotLH', fullfile(example_dir, 'lh.Schaefer2018_200Parcels_7Networks_order.annot'), 'color_x_brain', mymap('plasma'), ...
    'AnnotRH', fullfile(example_dir, 'rh.Schaefer2018_200Parcels_7Networks_order.annot'), 'color_y_brain', mymap('RdYlGn'), ...
    'UseSpin', false, 'xName', xName, 'yName', yName, 'CorrType', 'Spearman', ...
    'X_bar_name', 'xbar', 'Y_bar_name', 'ybar', 'x_limits', [-20,220], 'y_limits', [-20,220]);

exportgraphics(fig_handle1, fullfile(example_dir, ['Scatter_' xName '.tif']), 'Resolution', 300);
exportgraphics(fig_handle2, fullfile(example_dir, ['brain_' yName '.tif']), 'Resolution', 300);
exportgraphics(fig_quad, fullfile(example_dir, ['brain_quad_' yName '.tif']), 'Resolution', 300);
