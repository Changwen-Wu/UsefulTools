% Standalone four-view cortical map: one regional vector, no correlation plot.
% Requires fsaverage lh.cortex.label and rh.cortex.label under
% Brainplot/Parcellations/FreeSurfer5.3/fsaverage/label/.
example_dir = fileparts(mfilename('fullpath'));
brainplot_dir = fileparts(example_dir);
image_dir = fullfile(example_dir, 'images');
if ~isfolder(image_dir), mkdir(image_dir); end
addpath(brainplot_dir, fullfile(brainplot_dir, 'BasicTools'), ...
    fullfile(brainplot_dir, 'surf'), example_dir);

% Replace this synthetic vector with your own parcel values.
% Schaefer200: 100 left-hemisphere parcels followed by 100 right parcels.
rng(0, 'twister');
brain_data = rand(1, 200);
label_name = 'Value';
annot_lh = fullfile(example_dir, 'lh.Schaefer2018_200Parcels_7Networks_order.annot');
annot_rh = fullfile(example_dir, 'rh.Schaefer2018_200Parcels_7Networks_order.annot');
colors = mymap('RdYlGn');

% Top: left/right lateral. Bottom: left/right medial.
% Use the same scale as the quad output in example.m.
fig_quad = plot_quad_brain_map(brain_data, label_name, annot_lh, annot_rh, ...
    colors, 'CLim', [0, 1], 'scale_factor', 8 / 8.5);

exportgraphics(fig_quad, fullfile(image_dir, 'brain_quad_standalone.tif'), ...
    'Resolution', 300);
