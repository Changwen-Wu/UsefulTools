# Brainplot 示例

这里提供完整的相关性绘图示例，以及只绘制单个脑区向量的四视角（quad）脑图示例。示例使用固定随机种子的模拟数据；导出的 TIFF 图片均为 300 dpi。

## 文件组织

```text
example/
├── README.md
├── example.m                      # 相关性散点图与脑图
├── example_quad.m                 # 独立四视角脑图
├── mymap.m                        # 颜色映射
├── lh.Schaefer2018_200Parcels_7Networks_order.annot
├── rh.Schaefer2018_200Parcels_7Networks_order.annot
└── images/                        # 集中存放导出的示例图片
    ├── Scatter_testx.tif
    ├── brain_testy.tif
    ├── brain_quad_testy.tif
    └── brain_quad_standalone.tif
```

## 运行环境

- MATLAB；示例已在 R2025a 中运行验证。
- `example.m` 的相关性分析与拟合需要 Statistics and Machine Learning Toolbox。
- 保留完整的 `Brainplot` 目录，包括 `BasicTools/`、`surf/` 和 `Parcellations/`。两个脚本会自动添加绘图所需路径。
- 表面读取依赖 `BasicTools/` 中与操作系统匹配的 MEX 文件。

仓库已包含 `fsaverage`、`fsaverage5`、`fsaverage6` 的皮层标签，均从 `E:\Resources\GRETNA_CW\Parcellations\FreeSurfer5.3` 原样复制。当前示例使用 `fsaverage`，其所需表面文件已包含，并自动读取下面两个标签文件：

```text
Brainplot/Parcellations/FreeSurfer5.3/fsaverage/label/lh.cortex.label
Brainplot/Parcellations/FreeSurfer5.3/fsaverage/label/rh.cortex.label
```

本目录的 `.annot` 文件定义脑区分区；`lh.cortex.label` 和 `rh.cortex.label` 定义皮层范围。两者都需要。表面读取函数使用上述固定位置，不会仅根据 `FREESURFER_HOME` 自动查找这些文件。

迁移时请复制完整的 `Brainplot` 目录，保留各分辨率下的 `surf/` 与 `label/` 子目录；标签文件不能跨分辨率混用。GRETNA_CW 来源未提供的 `fsaverage5`、`fsaverage6` 左右半球球面文件，已从 FreeSurfer 官方服务器原样补齐，未经过转换或重采样。标签清单、球面来源与校验值见 [FreeSurfer5.3 文件说明](../Parcellations/FreeSurfer5.3/README.md)。

## 完整相关性示例

在 MATLAB 中打开并运行 [example.m](example.m)，或在本目录执行：

```matlab
run('example.m');
```

脚本调用 [plot_brain_correlation](../plot_brain_correlation.m)，输入两个长度为 200 的模拟脑区向量，并输出：

| 图片 | 内容 |
| --- | --- |
| [Scatter_testx.tif](images/Scatter_testx.tif) | Spearman 秩相关散点图、拟合线及 X 变量脑图 |
| [brain_testy.tif](images/brain_testy.tif) | Y 变量的左右半球外侧面脑图 |
| [brain_quad_testy.tif](images/brain_quad_testy.tif) | Y 变量的四视角脑图 |

模拟数据示例使用普通相关检验的 p 值（`UseSpin=false`）。实际皮层空间相关分析应另行提供经验证的 spin-test p 值或 `SpinMat`，不能把示例 p 值解释为空间自相关校正后的结果。

## 独立 quad 脑图示例

打开并运行 [example_quad.m](example_quad.m)，或在本目录执行：

```matlab
run('example_quad.m');
```

脚本调用从原函数提取的 [plot_quad_brain_map](../plot_quad_brain_map.m)，只需一个脑区向量，输出 [brain_quad_standalone.tif](images/brain_quad_standalone.tif)。上排为左、右半球外侧面，下排为左、右半球内侧面，底部为共用色条。

在脚本中可修改：

```matlab
brain_data = rand(1, 200);   % 替换为自己的脑区数据
label_name = 'Value';       % 色条名称
colors = mymap('RdYlGn');   % 配色

fig_quad = plot_quad_brain_map(brain_data, label_name, annot_lh, annot_rh, ...
    colors, 'CLim', [0, 1], 'scale_factor', 8 / 8.5);
```

`CLim` 控制色条范围；用于真实数据时应相应调整，省略该参数则使用数据最小值与最大值。`scale_factor` 控制布局尺寸和字号。

## 图片目录

四张示例图片统一放在 [images/](images/)。两个脚本均自动创建该目录，并将 300 dpi TIFF 图片导出到这里；再次运行会覆盖对应的图片。脚本和图谱输入文件位于本目录。

## 图谱文件

本目录提供 Schaefer2018 200 脑区、7 网络、`fsaverage` 空间的左右半球 `.annot` 文件。`lh` 表示左半球，`rh` 表示右半球；两个示例均通过脚本位置自动解析图谱路径。

替换图谱时，需要同时更换左右半球注释文件、核对表面空间，并使输入向量的长度及脑区顺序与图谱匹配。图谱背景与参考文献见 [FreeSurfer5.3 图谱说明](../Parcellations/FreeSurfer5.3/README.md)。
