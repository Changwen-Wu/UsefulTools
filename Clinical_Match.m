function [raw_final, p_stats, summary_str] = Clinical_Match(pheno_path, sheet_name, inclu_cri, match_cri, match_method, min_counts, site_col_name, dx_col_name, group_names)
% ABIDE_PICKER_FUNC  ABIDE 数据集自动化筛选与被试匹配工具
%
% 这是一个用于处理神经影像表型数据（如 ABIDE Phenotypic.xlsx）的函数。
% 它可以根据预设条件筛选被试（Inclusion Criteria），并利用贪婪算法或随机算法
% 自动剔除被试，以实现组间（如 ASD vs HC）人口学指标的统计学匹配。
%
% =========================================================================
% 输入参数 (INPUTS):
%
%   1. pheno_path (String):
%      表型数据 Excel 文件的路径。例如: 'C:\Data\ABIDE_Phenotypic.xlsx'
%
%   2. sheet_name (String):
%      Excel 中的表单名称。例如: 'Rest', 'Anat' 或 'Sheet1'
%
%   3. inclu_cri (Cell Array of Strings) - 【筛选标准】:
%      在匹配前执行的数据清洗规则。支持集合筛选、数值范围和反向剔除。
%
%      语法规则: '列名:条件'
%      ------------------------------------------------------------
%      符号       | 含义              | 示例
%      ------------------------------------------------------------
%      {A,B}      | 集合 (只选...)     | 'SITE_ID:{NYU, UCLA}' (只保留NYU和UCLA站点)
%      ~          | 排除 (不要...)     | 'SITE_ID:~{Caltech}'  (剔除Caltech站点)
%      [min, max] | 闭区间 (含边界)    | 'AGE:[6, 18]'         (6岁到18岁，包含6和18)
%      (min, max) | 开区间 (不含边界)  | 'FIQ:(80, 120)'       (IQ大于80且小于120)
%      [min, )    | 单侧区间 (大于...) | 'AGE:[18, )'          (18岁及以上)
%      ------------------------------------------------------------
%
%   4. match_cri (Cell Array of Strings) - 【匹配标准】:
%      定义组间需要平衡的指标。函数会努力使这些指标的组间差异 P > 0.05。
%
%      语法规则: '[*]检验方法:变量名~分组变量'
%      ------------------------------------------------------------
%      前缀   | 含义           | 适用场景 & 示例
%      ------------------------------------------------------------
%      T:     | T检验          | 连续变量。如: 'T:AGE_AT_SCAN~DX_GROUP'
%      X2:    | 卡方检验       | 分类变量。如: 'X2:SEX~DX_GROUP'
%      F:     | 方差分析       | 交互效应。如: 'F:AGE~DX_GROUP*SITE_ID'
%      * | 忽略缺失值     | 加在最前面。如: '*T:FIQ~DX_GROUP' (忽略没有IQ的人)
%      ------------------------------------------------------------
%
%   5. match_method (String):
%      匹配策略选择：
%      - 'Greedy': 贪婪算法（推荐）。迭代剔除对 P 值提升最大的个体。
%      - 'Random': 随机算法。随机抽取 10000 次，保留 P 值最高的那次。
%      - 'None'  : 不进行匹配，仅执行筛选。
%
%   6. min_counts (Vector):
%      [最小HC人数, 最小ASD人数]。例如 [5, 5]。
%      若某站点筛选后人数少于此阈值，该站点的所有数据将被剔除。
%
%   7. site_col_name (String):
%      你的 Excel 中代表"站点/中心"的列名。例如 'Site' 或 'Center_ID'。
%      如果不填，默认值为 'SITE_ID'。
%
%   8. dx_col_name (String):
%      你的 Excel 中代表"诊断分组"的列名。例如 'Group' 或 'Diagnosis'。
%      如果不填，默认值为 'DX_GROUP'。
%      【注意】该列的值目前仍需保持：1代表ASD(病人)，2代表HC(对照)。
%
%   9. group_names (Cell Array of Strings):
%      对应 min_counts 顺序的组名文本标签。
%
%      【对应关系】：
%      min_counts  = [  最小HC数量,   最小ASD数量  ]
%      group_names = { 'ControlName', 'PatientName' }
%
%      示例:
%      如果 min_counts = [10, 5] (希望对照组>10人, 病人组>5人)
%      且 Excel 中是用 'Control' 和 'Autism' 表示的，
%      则输入: {'Control', 'Autism'}
%
%      如果不填或留空，默认 Excel 中已经是数字 1(ASD) 和 2(HC)。
%
% =========================================================================
% 输出参数 (OUTPUTS):
%   raw_final   : (Cell Array) 处理后的最终数据表（包含表头）。
%   p_stats     : (Struct) 包含最终的统计 P 值 (p_whole, p_sep)。
%   summary_str : (String) 格式化的文本报告，包含各站点人数及匹配 P 值。
%
% =========================================================================
% 使用示例 (EXAMPLE):
%
%   % 1. 定义筛选条件：只要男性，年龄小于30，只要 ASD(1) 和 HC(2) 组
%   inclu = {
%       'SEX:{1}';
%       'AGE_AT_SCAN:(,30)';
%       'DX_GROUP:{1,2}'
%   };
%
%   % 2. 定义匹配条件：匹配年龄(T检验)，匹配站点分布(卡方)，匹配IQ(T检验,忽略缺失值)
%   match = {
%       'T:AGE_AT_SCAN~DX_GROUP';
%       'X2:SITE_ID~DX_GROUP';
%       '*T:FIQ~DX_GROUP'
%   };
%
%   % 3. 执行函数
%   [data, stats, report] = ABIDE_Picker_Func('Phenotypic.xlsx', 'Sheet1', ...
%                                             inclu, match, 'Greedy', [10, 10]);
%   disp(report);
%
% =========================================================================

%% 0. 参数默认值与基础设置
if nargin < 7 || isempty(site_col_name), site_col_name = 'SITE_ID'; end
if nargin < 8 || isempty(dx_col_name), dx_col_name = 'DX_GROUP'; end
if nargin < 9, group_names = {}; end

%% 1. 数据加载
fprintf('Loading data from %s (%s)...\n', pheno_path, sheet_name);
try
    [~, ~, raw] = xlsread(pheno_path, sheet_name);
catch ME
    error('Failed to read Excel file. Check path or sheet name.\nError: %s', ME.message);
end
header = strtrim(raw(1,:)); % 去除表头空格，防止 " AGE" 这种坑
raw(1,:) = header;          % 更新回去

% 清理空的筛选标准
if ~isempty(inclu_cri)
    inclu_cri(cellfun(@isempty, inclu_cri)) = [];
end

%% ============================================================
%% 1.2 全面预检查 (Validate Inputs BEFORE Processing)
%% ============================================================
fprintf('Validating inputs and criteria...\n');

% [检查1] 核心列是否存在
if ~ismember(site_col_name, header)
    error('CRITICAL: Site column "%s" NOT found in Excel header.', site_col_name);
end
if ~ismember(dx_col_name, header)
    error('CRITICAL: Diagnosis column "%s" NOT found in Excel header.', dx_col_name);
end

% [检查2] 筛选标准 (Inclusion Criteria) 检查
if ~isempty(inclu_cri)
    for i = 1:length(inclu_cri)
        cri_str = inclu_cri{i};
        tokens = regexp(cri_str, '^([^:]+):', 'tokens');
        if isempty(tokens)
            error('Syntax Error in inclu_cri line %d: "%s". Format must be "ColName:Condition".', i, cri_str);
        end
        col_name = strtrim(tokens{1}{1});
        if ~ismember(col_name, header)
            error('Column Error in inclu_cri: Column "%s" does not exist in the data.', col_name);
        end
    end
end

% [检查3] 匹配标准 (Match Criteria) 检查
if ~isempty(match_cri)
    for i = 1:length(match_cri)
        cri_str = match_cri{i};
        % 去除忽略标志 *
        if startsWith(cri_str, '*'), cri_str = cri_str(2:end); end

        % 解析 T:Age~Group
        parts = regexp(cri_str, ':', 'split');
        if length(parts) < 2
            error('Syntax Error in match_cri line %d: "%s". Missing ":".', i, match_cri{i});
        end

        formula_part = parts{2}; % Age~Group
        vars = regexp(formula_part, '[~*]', 'split'); % 分割变量

        for v = 1:length(vars)
            v_name = strtrim(vars{v});
            if ~ismember(v_name, header)
                error('Column Error in match_cri line %d: Column "%s" does not exist in the data.', i, v_name);
            end

            % [检查3.1] 数据类型预判 (防止 T 检验用了文本列)
            col_data = raw(2:end, strcmp(header, v_name));
            % 尝试拿到这一列的前10个非空值看看是不是纯文本
            sample_data = col_data(1:min(10, end));
            is_text = any(cellfun(@ischar, sample_data));

            test_type = lower(strtrim(parts{1}));
            if strcmp(test_type, 't') && is_text
                warning('Potential Logic Error in match_cri line %d: You are using T-test on column "%s", which seems to contain TEXT. T-test requires numbers.', i, v_name);
            end
        end
    end
end

% [检查4] 组名检查
if ~isempty(group_names)
    dx_idx = find(strcmp(header, dx_col_name));
    dx_data = raw(2:end, dx_idx);
    % 检查 group_names 是否真的存在于数据中
    unique_vals = unique(cellfun(@num2str, dx_data(cellfun(@isnumeric, dx_data)), 'UniformOutput', false)); % 统一转字符处理
    text_vals = unique(dx_data(cellfun(@ischar, dx_data)));
    all_vals = [unique_vals; text_vals];

    if ~ismember(group_names{1}, all_vals)
        warning('Group Name Warning: "%s" was NOT found in column "%s". Check spelling or spaces.', group_names{1}, dx_col_name);
    end
    if ~ismember(group_names{2}, all_vals)
        warning('Group Name Warning: "%s" was NOT found in column "%s". Check spelling or spaces.', group_names{2}, dx_col_name);
    end
end

fprintf('  -> Validation Passed. Starting processing.\n');


%% 1.5 文本标签转数字 (Text -> Number)
if ~isempty(group_names)
    name_for_HC = group_names{1};  % Map to 2
    name_for_ASD = group_names{2}; % Map to 1
    dx_idx_raw = find(strcmp(header, dx_col_name));

    convert_count = 0;
    for r = 2:size(raw, 1)
        val = raw{r, dx_idx_raw};
        if ischar(val)
            val = strtrim(val);
            if strcmp(val, name_for_ASD)
                raw{r, dx_idx_raw} = 1; convert_count = convert_count + 1;
            elseif strcmp(val, name_for_HC)
                raw{r, dx_idx_raw} = 2; convert_count = convert_count + 1;
            end
        end
    end
    fprintf('Mapped %d rows to numeric IDs based on group_names.\n', convert_count);
end

%% 2. 基础筛选 (Inclusion Criteria)
[raw_simp, header_simp, cri_simp] = simplify_cri(raw, header, inclu_cri);
inclu_idx_logic = pick_sub(raw_simp, header_simp, cri_simp);
inclu_idx = [1; inclu_idx_logic];
raw_inclu = raw(inclu_idx == 1, :);

%% 3. 站点样本量筛选 (Site Threshold)
cri_num_HC = min_counts(1);
cri_num_ASD = min_counts(2);
[raw_filtered, ~] = thre_sub_num(raw_inclu, cri_num_HC, cri_num_ASD, site_col_name, dx_col_name);
raw_final = raw_filtered;

%% 4. 数据匹配 (Matching)
if strcmpi(match_method, 'None')
    fprintf('Skipping matching process...\n');
else
    fprintf('Starting matching process using method: %s...\n', match_method);
    [cri_type, val_header, val_cat, ~, cri_category, ignore_nan, valid_criteria] = parse_match_criteria(raw_final, match_cri);

    if valid_criteria
        if strcmpi(match_method, 'greedy')
            [raw_final] = match_greedy(raw_final, cri_type, val_header, val_cat, ignore_nan);
        elseif strcmpi(match_method, 'random')
            [raw_final] = match_random(raw_final, cri_type, val_header, val_cat, ignore_nan, dx_col_name);
        end
    else
        warning('No valid matching criteria found.');
    end
end

%% 5. 计算最终统计量与生成报告
[cri_type, val_header, val_cat, cri_header, cri_category, ignore_nan, valid_criteria] = parse_match_criteria(raw_final, match_cri);
if valid_criteria
    ignore_nan_final = ones(length(cri_type), 1);
    [p_whole, p_sep] = match_cal_p(cri_type, val_header, val_cat, ignore_nan_final);
else
    p_whole = -1;
    p_sep = [];
end
p_stats.p_whole = p_whole;
p_stats.p_sep = p_sep;

%% 6. 还原数字回文本 & 生成报告
if ~isempty(group_names)
    dx_idx_final = find(strcmp(strtrim(raw_final(1,:)), dx_col_name));
    for r = 2:size(raw_final, 1)
        val = raw_final{r, dx_idx_final};
        if val == 1, raw_final{r, dx_idx_final} = group_names{2};
        elseif val == 2, raw_final{r, dx_idx_final} = group_names{1};
        end
    end
    summary_str = generate_summary(raw_final, p_sep, cri_type, cri_header, cri_category, site_col_name, dx_col_name, group_names);
else
    summary_str = generate_summary(raw_final, p_sep, cri_type, cri_header, cri_category, site_col_name, dx_col_name, {'HC', 'ASD'});
end

fprintf('--------------------------------------------------\n');
fprintf(summary_str);
fprintf('--------------------------------------------------\n');
end


%% ================== Helper Functions (Unchanged Logic) ==================

function [raw_simp, header_simp, cri_simp] = simplify_cri(raw, header, inclu_cri)
[cri_trim] = regexp(inclu_cri, '^([^#]+)#?.*$', 'tokens');
inclu_idx = [];
for i = 1:length(cri_trim)
    cri_tmp = cri_trim{i}{1}{1};
    head_tmp = regexp(cri_tmp, '^[^:]+', 'match');
    head_tmp = strtrim(head_tmp{1});
    for j = 1:length(header)
        if(strcmp(head_tmp, strtrim(header{j})))
            inclu_idx = [inclu_idx, j];
            break;
        end
    end
end
if isempty(inclu_idx)
    raw_simp = raw;
    header_simp = header;
else
    raw_simp = raw(:, unique(inclu_idx));
    header_simp = header(:, unique(inclu_idx));
end
cri_simp = cri_trim;
end

function inclu_idx = pick_sub(raw_simp, header_simp, cri_simp)
inclu_idx = ones(size(raw_simp, 1)-1, 1);
for i = 1:length(cri_simp)
    cri_tmp = regexp(cri_simp{i}{1}{1}, '^([^:]+):([^:]+)$', 'tokens');
    if isempty(cri_tmp), continue; end
    cri_head = strtrim(cri_tmp{1}{1});
    cri_main = strtrim(cri_tmp{1}{2});
    header_idx = -1;
    for j = 1:length(header_simp)
        if(strcmp(cri_head, strtrim(header_simp{j})))
            header_idx = j;
            break;
        end
    end

    if(header_idx == -1), error('Incorrect criteria header: %s', cri_head); end

    idx_tmp = zeros(size(raw_simp, 1)-1, 1);
    exclu_flag = 0;
    if(cri_main(1) == '~'), exclu_flag = 1; cri_main(1) = []; end
    if(cri_main(1) == '{')
        cri_main_tmp = cri_main(2:end-1);
        cri_value = regexp(cri_main_tmp, ',', 'split');
        for j = 1:length(cri_value)
            cri_value_tmp = strtrim(cri_value{j});
            for k = 2:size(raw_simp, 1)
                raw_simp_tmp = raw_simp{k, header_idx};
                if(~ischar(raw_simp_tmp)), raw_simp_tmp = num2str(raw_simp_tmp); end
                raw_tmp = strtrim(raw_simp_tmp);
                if(strcmpi(cri_value_tmp, raw_tmp)), idx_tmp(k-1) = 1; end
            end
        end
    else
        if(cri_main(1) == '['), inclu_left = 1; elseif(cri_main(1) == '('), inclu_left = 0; end
        if(cri_main(end) == ']'), inclu_right = 1; elseif(cri_main(end) == ')'), inclu_right = 0; end
        cri_main_tmp = cri_main(2:end-1);
        cri_value = regexp(cri_main_tmp, ',', 'split');
        raw_tmp_data = raw_simp(2:end, header_idx);
        raw_tmp = nan(length(raw_tmp_data), 1);
        for k = 1:length(raw_tmp_data)
            if isnumeric(raw_tmp_data{k}) && ~isempty(raw_tmp_data{k})
                raw_tmp(k) = raw_tmp_data{k};
            elseif ischar(raw_tmp_data{k})
                raw_tmp(k) = str2double(raw_tmp_data{k});
            end
        end
        cri_value_left = str2double(cri_value{1});
        cri_value_right = str2double(cri_value{2});
        if(~isnan(cri_value_left))
            if(inclu_left), idx_tmp(raw_tmp >= cri_value_left) = 1; else, idx_tmp(raw_tmp > cri_value_left) = 1; end
        end
        if(~isnan(cri_value_right))
            if(inclu_right), idx_tmp(raw_tmp <= cri_value_right) = 1; else, idx_tmp(raw_tmp < cri_value_right) = 1; end
        end
    end
    if(exclu_flag), idx_tmp = 1 - idx_tmp; end
    raw_simp_nan = raw_simp(:, header_idx);
    for j = 2:length(raw_simp_nan)
        if(isnumeric(raw_simp_nan{j}) && isnan(raw_simp_nan{j})) || (ischar(raw_simp_nan{j}) && isempty(raw_simp_nan{j})), idx_tmp(j-1) = 0; end
    end
    inclu_idx = inclu_idx .* idx_tmp;
end
end

function [raw_final, ex_idx] = thre_sub_num(raw_inclu, cri_num_HC, cri_num_ASD, site_col, dx_col)
header_inclu = raw_inclu(1, :);
site_idx = find(strcmp(strtrim(header_inclu), site_col));
dx_idx = find(strcmp(strtrim(header_inclu), dx_col));
raw_site = raw_inclu(2:end, site_idx);
raw_dx = cell2mat(raw_inclu(2:end, dx_idx));
site_unique = unique(raw_site);
ex_idx = zeros(size(raw_inclu, 1)-1, 1);
for i = 1:length(site_unique)
    idx_tmp = strcmp(site_unique{i}, raw_site);
    dx_tmp = raw_dx(idx_tmp);
    if(sum(dx_tmp == 1) < cri_num_ASD)
        ex_idx(idx_tmp) = 1; continue;
    elseif(sum(dx_tmp == 2) < cri_num_HC)
        ex_idx(idx_tmp) = 1; continue;
    end
end
ex_idx_full = [0; ex_idx];
raw_final = raw_inclu(ex_idx_full == 0, :);
end

function [cri_type, val_header, val_cat, cri_header, cri_category, ignore_nan, valid] = parse_match_criteria(raw_data, match_cri)
header = strtrim(raw_data(1,:));
ignore_nan = zeros(length(match_cri), 1);
empty_flag = 1;
cri_type = {}; val_header = {}; val_cat = {}; cri_header = {}; cri_category = {};
for i = 1:length(match_cri)
    cri_tmp = match_cri{i};
    if(isempty(cri_tmp)), continue; end
    empty_flag = 0;
    if(cri_tmp(1) == '*'), ignore_nan(i) = 1; cri_tmp(1) = []; end
    [idx_a, idx_p] = regexp(cri_tmp, '^[^:]+');
    cri_type{i} = cri_tmp(idx_a:idx_p);
    cri_tmp(idx_a:idx_p+1) = [];
    [idx_a, idx_p] = regexp(cri_tmp, '^[^~]+');
    cri_header{i} = cri_tmp(idx_a:idx_p);
    cri_tmp(idx_a:idx_p+1) = [];
    val_header{i} = raw_data(2:end, strcmp(header, cri_header{i}));
    if(strcmpi(cri_type{i}, 'f'))
        cri_category{i} = regexp(cri_tmp, '*', 'split');
        for j = 1:length(cri_category{i}), val_cat{i}{j} = raw_data(2:end, strcmp(cri_category{i}{j}, header)); end
    else
        cri_category{i} = cri_tmp;
        val_cat{i} = raw_data(2:end, strcmp(cri_category{i}, header));
    end
end
valid = ~empty_flag;
end

function [p_score, p_sep] = match_cal_p(cri_type, val_header, val_cat, ignore_nan)
    p_sep = zeros(length(cri_type), 1);
    for i = 1:length(cri_type)
        type_tmp = cri_type{i};
        val_header_tmp = val_header{i};
        val_cat_tmp = val_cat{i};
        
        % --- [FIX] Safer NaN Handling & Data Conversion ---
        if strcmpi(type_tmp, 't') || strcmpi(type_tmp, 'f')
            % Convert cell to numeric safely (empty becomes NaN)
            v_temp = nan(size(val_header_tmp));
            for k=1:numel(val_header_tmp)
                if isnumeric(val_header_tmp{k}) && ~isempty(val_header_tmp{k})
                    v_temp(k) = val_header_tmp{k};
                elseif ischar(val_header_tmp{k})
                    v_temp(k) = str2double(val_header_tmp{k});
                end
            end
            val_header_tmp = v_temp;
        end
        
        % NaN Indexing
        if(strcmpi(type_tmp, 't'))
            idx_nan_header = isnan(val_header_tmp);
            idx_nan_cat = cellfun(@(x) sum(isnan(x))>0 || isempty(x), val_cat_tmp);
            idx_nan = idx_nan_header | idx_nan_cat;
        elseif(strcmpi(type_tmp, 'f'))
            idx_nan_header = isnan(val_header_tmp);
            idx_nan_cat = ones(length(val_header_tmp), 1);
            for j = 1:length(val_cat_tmp)
                idx_nan_cat = idx_nan_cat .* cellfun(@(x) sum(isnan(x))>0 || isempty(x), val_cat_tmp{j});
            end
            idx_nan = idx_nan_header | idx_nan_cat;
        elseif(strcmpi(type_tmp, 'x2'))
            idx_nan_header = cellfun(@(x) sum(isnan(x))>0 || isempty(x), val_header_tmp);
            idx_nan_cat = cellfun(@(x) sum(isnan(x))>0 || isempty(x), val_cat_tmp);
            idx_nan = idx_nan_header | idx_nan_cat;
        end
        
        % Handle NaN Removal
        if(sum(idx_nan) > 0)
            if(ignore_nan(i) == 1)
                val_header_tmp(idx_nan) = [];
                if strcmpi(type_tmp, 'f') && iscell(val_cat_tmp)
                    for j=1:length(val_cat_tmp), val_cat_tmp{j}(idx_nan) = []; end
                elseif iscell(val_cat_tmp) % Rare case for t/x2 if cell input
                     val_cat_tmp(idx_nan) = [];
                else
                     val_cat_tmp(idx_nan) = [];
                end
            else
                error('NaN detected. Use * to ignore.');
            end
        end
        
        % Statistics
        try
            if(strcmpi(type_tmp, 't'))
                try, [~, ~, cat_tmp_uniqu] = unique(val_cat_tmp); catch, [~, ~, cat_tmp_uniqu] = unique(cell2mat(val_cat_tmp)); end
                if(max(cat_tmp_uniqu) ~= 2), p_sep(i) = 0; else, [~, p_sep(i)] = ttest2(val_header_tmp(cat_tmp_uniqu == 1), val_header_tmp(cat_tmp_uniqu == 2)); end
            elseif(strcmpi(type_tmp, 'f'))
                cat_tmp_uniqu = {};
                for j = 1:length(val_cat_tmp)
                    try, [~, ~, cat_tmp_uniqu{j}] = unique(val_cat_tmp{j}); catch, [~, ~, cat_tmp_uniqu{j}] = unique(cell2mat(val_cat_tmp{j})); end
                end
                if(length(cat_tmp_uniqu) == 1)
                    p_sep(i) = anova1(val_header_tmp, cat_tmp_uniqu{1}, 'off');
                else
                    p_tmp = anovan(val_header_tmp, cat_tmp_uniqu, 'model', 'interaction', 'display', 'off');
                    p_sep(i) = p_tmp(3);
                end
            elseif(strcmpi(type_tmp, 'x2'))
                try, [~, ~, header_tmp_uniqu] = unique(val_header_tmp); catch, [~, ~, header_tmp_uniqu] = unique(cell2mat(val_header_tmp)); end
                try, [~, ~, cat_tmp_uniqu] = unique(val_cat_tmp); catch, [~, ~, cat_tmp_uniqu] = unique(cell2mat(val_cat_tmp)); end
                [~, ~, p_sep(i)] = crosstab(header_tmp_uniqu, cat_tmp_uniqu);
            end
        catch
            p_sep(i) = 0;
        end
    end
    
    % ---------------- [Optimization Objective: Harmonic Mean] ----------------
    % Harmonic mean heavily penalizes low values, ensuring all variables are balanced.
    valid_p = p_sep(~isnan(p_sep));
    valid_p = max(valid_p, 1e-10); % Avoid division by zero
    
    if isempty(valid_p)
        p_score = 0;
    else
        % Harmonic Mean Formula: n / sum(1/xi)
        p_score = length(valid_p) / sum(1 ./ valid_p);
    end
    % -----------------------------------------------------------------------
end

function [raw_final] = match_greedy(raw_final, cri_type, val_header, val_cat, ignore_nan)
    % ----------------------------------------------
    % [配置区]
    target_p = 0.15;   % 停止阈值
    batch_size = 1;    % 每次剔除的人数
                       % 设为 1 = 原版最慢最精准
                       % 设为 5 或 10 = 速度提升 5-10 倍，精度略微下降
    % ----------------------------------------------

    % 初始检查
    [~, p_vec] = match_cal_p(cri_type, val_header, val_cat, ignore_nan);
    if isempty(p_vec), min_p = 0; else, min_p = min(p_vec(~isnan(p_vec))); end
    
    if min_p >= target_p
        fprintf('Initial data matched (min P = %.4f). No removal.\n', min_p);
        return;
    end

    ex_id = [];
    total_subjects = length(val_header{1});
    
    iter_count = 0; % 记录循环次数
    
    % 主循环
    while length(ex_id) < total_subjects - 2
        iter_count = iter_count + 1;
        
        % 1. 刹车检查
        [vh_curr, vc_curr] = match_exclude(cri_type, val_header, val_cat, ex_id);
        [~, p_vec_curr] = match_cal_p(cri_type, vh_curr, vc_curr, ignore_nan);
        
        current_min_p = min(p_vec_curr(~isnan(p_vec_curr)));
        if isempty(current_min_p), current_min_p = 0; end
        
        if current_min_p >= target_p
            fprintf('  -> Target reached (min P = %.4f >= %.2f). Stopping.\n', current_min_p, target_p);
            break;
        end
        
        % 2. 寻找最佳剔除对象
        % 计算每个人被剔除后的得分
        scores = zeros(total_subjects, 1);
        % 并行计算可以用 parfor，这里用普通 for
        for j = 1:total_subjects
            if(any(ex_id == j))
                scores(j) = -Inf; % 已经被剔除的，给个极小分
                continue; 
            end
            
            ex_id_temp = [ex_id, j];
            [vh_t, vc_t] = match_exclude(cri_type, val_header, val_cat, ex_id_temp);
            scores(j) = match_cal_p(cri_type, vh_t, vc_t, ignore_nan);
        end
        
        % 3. [加速修改]：一次选出 batch_size 个得分最高的人
        [sorted_scores, sorted_idx] = sort(scores, 'descend');
        
        % 找出还没有被剔除的前 N 个候选人
        best_candidates = sorted_idx(1:batch_size);
        
        % 检查最高分是否有效
        best_score = sorted_scores(1);
        if best_score == 0 || isnan(best_score) || best_score == -Inf, break; end
        
        if(rem(iter_count, 1) == 0) % 每一步都打印，因为它代表删了一批人
            fprintf('Greedy Iter %d: Removing %d subjects. Best Score=%.4f | Min P=%.4f\n', ...
                iter_count, length(best_candidates), best_score, current_min_p);
        end
        
        % 批量加入剔除名单
        ex_id = [ex_id, best_candidates']; 
    end
    
    raw_final(ex_id + 1, :) = []; 
end


function [raw_final] = match_random(raw_final, cri_type, val_header, val_cat, ignore_nan, dx_col)
    dx_col_idx = find(strcmp(raw_final(1,:), dx_col));
    dx = cell2mat(raw_final(2:end, dx_col_idx));
    num_ASD = sum(dx == 1);
    num_HC = sum(dx == 2);
    diff_num = num_ASD - num_HC;
    
    if(diff_num == 0), fprintf('Groups already balanced. No random removal needed.\n'); return; end
    if(diff_num > 0), dx_ex = 1; else, dx_ex = 2; diff_num = abs(diff_num); end
    
    target_indices = find(dx == dx_ex);
    best_score = -1; 
    ex_id_best = [];
    
    fprintf('Running 10000 random permutations (Harmonic Mean)...\n');
    for i = 1:10000
        idx_tmp = randperm(length(target_indices));
        to_remove_local = idx_tmp(1:diff_num);
        ex_idx_g = target_indices(to_remove_local);
        
        [val_header_tmp, val_cat_tmp] = match_exclude(cri_type, val_header, val_cat, ex_idx_g);
        
        % Use Output 1 (Harmonic Mean Score) for comparison
        [score_now, ~] = match_cal_p(cri_type, val_header_tmp, val_cat_tmp, ignore_nan);
        
        if score_now > best_score
            best_score = score_now;
            ex_id_best = ex_idx_g;
        end
    end
    
    % --- [CORRECTED DELETION LOGIC] ---
    raw_final(ex_id_best + 1, :) = [];
end

function [val_header_out, val_cat_out] = match_exclude(cri_type, val_header, val_cat, ex_id)
val_header_out = val_header;
val_cat_out = val_cat;
if isempty(ex_id), return; end
for i = 1:length(val_header), val_header_out{i}(ex_id) = []; end
for i = 1:length(val_cat)
    if(strcmpi(cri_type{i}, 'f'))
        for j = 1:length(val_cat{i}), val_cat_out{i}{j}(ex_id) = []; end
    else
        val_cat_out{i}(ex_id) = [];
    end
end
end

function str = generate_summary(raw_final, p_sep, cri_type, cri_header, cri_category, site_col, dx_col, group_names)
str = 'Result Summary:\n\n';
if ~isempty(p_sep)
    str = [str, 'Match Statistics (P-values):\n'];
    for i = 1:length(p_sep)
        str_tmp = [cri_type{i}, ' : ', cri_header{i}, ' ~ '];
        if(strcmpi(cri_type{i}, 'f'))
            for j = 1:length(cri_category{i}), str_tmp = [str_tmp, cri_category{i}{j}, '*']; end
            str_tmp(end) = [];
        else
            str_tmp = [str_tmp, cri_category{i}];
        end
        str_tmp = [str_tmp, ' : ', num2str(p_sep(i))];
        str = [str, str_tmp, '\n'];
    end
end

str = [str, '\nSubjects Number per Site:\n'];
name1 = group_names{1};
name2 = group_names{2};

str = [str, sprintf('                | %-10s %-10s\n', name1, name2)];
str = [str, '--------------------------------------------\n'];

dx_idx = strcmp(raw_final(1,:), dx_col);
site_idx = strcmp(raw_final(1,:), site_col);

DX_GROUP = raw_final(2:end, dx_idx);
SITE_ID = raw_final(2:end, site_idx);

[site_uniq, ~, site_idx_num] = unique(SITE_ID);
dx_col_data = raw_final(2:end, dx_idx);

count_grp1 = @(idx_mask) sum(cellfun(@(x) (ischar(x) && strcmp(x, name1)) || (isnumeric(x) && x==2), dx_col_data(idx_mask)));
count_grp2 = @(idx_mask) sum(cellfun(@(x) (ischar(x) && strcmp(x, name2)) || (isnumeric(x) && x==1), dx_col_data(idx_mask)));

total_grp1 = count_grp1(true(size(dx_col_data)));
total_grp2 = count_grp2(true(size(dx_col_data)));

str = [str, sprintf('WHOLE           | %-10d %-10d\n', total_grp1, total_grp2)];

for i = 1:length(site_uniq)
    site_name = site_uniq{i};
    if isnumeric(site_name), site_name = num2str(site_name); end
    len_pad = 16 - length(site_name);
    if len_pad > 0, site_name = [site_name, repmat(' ', 1, len_pad)]; end

    site_mask = (site_idx_num == i);
    n_g1 = count_grp1(site_mask);
    n_g2 = count_grp2(site_mask);

    str = [str, sprintf('%s| %-10d %-10d\n', site_name, n_g1, n_g2)];
end
end