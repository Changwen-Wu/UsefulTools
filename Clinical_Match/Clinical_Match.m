function [raw_final, p_stats, summary_str] = Clinical_Match(pheno_path, sheet_name, inclu_cri, ...
    match_cri, match_method, min_counts, site_col_name, dx_col_name, group_names, target_p)
% CLINICAL_MATCH  临床研究被试筛选与协变量平衡工具箱
%
% 功能概述：
%   本函数用于处理多中心临床表型数据，旨在实现组间（如 ASD vs HC）人口学特征及
%   其他协变量的统计学平衡。
%   程序首先根据预设的纳入标准（Inclusion Criteria）执行数据清洗，随后利用
%   迭代算法（贪婪算法或模拟退火）自动识别并剔除导致组间差异显著的离群被试，
%   直至所有目标协变量的组间差异 P 值达到预设阈值（默认 P > 0.15）。
%
% =========================================================================
% 【核心算法逻辑 (Algorithm Logic)】
%
%   1. 优化目标函数 (Objective Function):
%      - 使用 P 值的 调和平均数 (Harmonic Mean) 作为评估当前样本集合质量的评分标准。
%      - 公式: Score = N / sum(1 ./ P_values)
%      - 特性: 调和平均数对极小值敏感。该机制迫使算法优先优化差异最显著（P值最小）
%        的变量，避免出现"短板效应"，确保多维协变量的同步平衡。
%
%   2. 贪婪算法 (Greedy Algorithm):
%      - 类型: 确定性局部优化算法。
%      - 机制: 在每一次迭代中，计算剔除候选池中每一位被试后的评分变化，
%        并严格选择能使当前评分提升幅度最大的被试进行剔除。
%      - 特点: 结果稳定可复现，收敛速度较快；但在复杂解空间中容易陷入局部最优解，
%        可能导致过度剔除。
%
%   3. 模拟退火算法 (Simulated Annealing, SA):
%      - 类型: 概率性全局优化算法。
%      - 机制: 引入"温度"参数 (Temperature) 控制搜索过程的随机性。
%        - 高温阶段: 算法具有较高的概率接受非最优的剔除操作（Metropolis 准则），
%          以此跳出局部最优陷阱，探索解空间。
%        - 冷却过程: 随着迭代进行，温度按几何级数衰减，算法逐渐收敛为贪婪策略，
%          专注于局部精细搜索。
%      - 特点: 通过引入随机扰动，有更高概率找到全局最优解（即在满足统计平衡的前提下
%        保留更多的样本量）。
%
%   4. 随机抽样 (Random Permutation):
%      - 机制: 执行多次（默认10000次）蒙特卡洛随机抽样，随机剔除多余被试，
%        并返回其中统计平衡性最好的一组结果。
%      - 用途: 通常作为算法性能评估的基准线 (Baseline)。
%
% =========================================================================
% 输入参数 (INPUTS):
%
%   1. pheno_path (String): 数据文件绝对路径 (.xlsx / .csv)。
%   2. sheet_name (String): Excel 表单名。CSV 文件可留空。
%
%   3. inclu_cri (Cell Array): 硬性筛选标准。
%      支持集合运算与区间运算。语法: '列名:条件'
%      - 集合: 'SITE:{NYU, UCLA}' (仅保留 NYU 和 UCLA)
%      - 排除: 'SITE:~{Caltech}'  (剔除 Caltech)
%      - 区间: 'AGE:[18, 60]' (闭区间), 'FIQ:(, 120)' (开区间)
%
%   4. match_cri (Cell Array): 统计匹配/平衡标准。
%      目标是使组间差异 P > 0.15。语法: '[*]检验方法:变量名~分组'
%      - T检验: 'T:AGE~GROUP' (用于连续变量)
%      - 卡方:  'X2:SEX~GROUP' (用于分类变量)
%      - 方差分析: 'F:AGE~GROUP*SITE' (用于交互效应或多组比较)
%      - 前缀 *: '*T:FIQ~GROUP' (忽略该列中的 NaN 值)
%
%   5. match_method (String): 匹配策略选择。
%      - 'Greedy'    : 贪婪算法 (推荐作为快速基准)。
%      - 'Annealing' : 模拟退火算法 (推荐，建议多次运行取最佳)。
%      - 'Random'    : 随机抽样。
%      - 'None'      : 仅执行 inclu_cri 筛选，不进行统计匹配。
%
%   6. min_counts (Vector): [Control最少人数, Patient最少人数]。
%      若某站点在筛选后任一组人数低于此阈值，该站点数据将被完全剔除。
%
%   7. site_col_name (String): 站点/中心 列名 (如 'SITE_ID')。
%   8. dx_col_name (String):   分组/诊断 列名 (如 'DX_GROUP')。
%   9. group_names (Cell):     分组标签 (如 {'HC', 'ASD'})，用于输出报告。
%
% =========================================================================
% 输出参数 (OUTPUTS):
%   raw_final   : (Cell)   匹配完成后的最终数据表。
%   p_stats     : (Struct) 包含各匹配指标的最终 P 值及统计量。
%   summary_str : (String) 格式化的统计报告（含各站点样本分布及最终 P 值）。
% =========================================================================

%% 0. 参数默认值与基础设置
if nargin < 7 || isempty(site_col_name), site_col_name = 'SITE_ID'; end
if nargin < 8 || isempty(dx_col_name), dx_col_name = 'DX_GROUP'; end
if nargin < 9, group_names = {}; end

% 初始化随机种子
rng('shuffle');

%% 1. 数据加载
fprintf('Loading data from %s (%s)...\n', pheno_path, sheet_name);
try
    [~, ~, raw] = xlsread(pheno_path, sheet_name);
catch ME
    error('Failed to read Excel file. Check path or sheet name.\nError: %s', ME.message);
end
header = strtrim(raw(1,:));
raw(1,:) = header;

if ~isempty(inclu_cri)
    inclu_cri(cellfun(@isempty, inclu_cri)) = [];
end

%% ============================================================
%% 1.2 全面预检查
%% ============================================================
fprintf('Validating inputs and criteria...\n');
if ~ismember(site_col_name, header)
    error('CRITICAL: Site column "%s" NOT found in Excel header.', site_col_name);
end
if ~ismember(dx_col_name, header)
    error('CRITICAL: Diagnosis column "%s" NOT found in Excel header.', dx_col_name);
end
% 简单检查筛选标准
if ~isempty(inclu_cri)
    for i = 1:length(inclu_cri)
        cri_str = inclu_cri{i};
        tokens = regexp(cri_str, '^([^:]+):', 'tokens');
        if isempty(tokens)
            error('Syntax Error in inclu_cri line %d: "%s".', i, cri_str);
        end
        col_name = strtrim(tokens{1}{1});
        if ~ismember(col_name, header)
            error('Column Error in inclu_cri: Column "%s" missing.', col_name);
        end
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
    [cri_type, val_header, val_cat, ~, ~, ignore_nan, valid_criteria] = parse_match_criteria(raw_final, match_cri);

    if valid_criteria
        s_idx = find(strcmp(header, site_col_name));
        g_idx = find(strcmp(header, dx_col_name));
        site_data = raw_final(2:end, s_idx);
        group_data = raw_final(2:end, g_idx);

        if strcmpi(match_method, 'greedy')
            % 贪婪算法
            [raw_final] = match_greedy(raw_final, cri_type, val_header, val_cat, ignore_nan, site_data, group_data, min_counts, target_p);

        elseif strcmpi(match_method, 'annealing')
            % 模拟退火算法
            [raw_final] = match_annealing(raw_final, cri_type, val_header, val_cat, ignore_nan, site_data, group_data, min_counts, target_p);

        elseif strcmpi(match_method, 'random')
            % 随机算法
            [raw_final] = match_random(raw_final, cri_type, val_header, val_cat, ignore_nan, dx_col_name);
        else
            warning('Unknown match method. Use Greedy, Annealing, or Random.');
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

%% ================== Helper Functions ==================

function [raw_final] = match_greedy(raw_final, cri_type, val_header, val_cat, ignore_nan, site_data, group_data, min_counts, target_p)
% ----------------------------------------------
% 贪婪算法实现
% ----------------------------------------------
batch_size = 1;

% 数据预处理 (站点/分组 ID 化)
if iscell(site_data)
    if any(cellfun(@isnumeric, site_data)), site_data = cellfun(@(x) char(string(x)), site_data, 'UniformOutput', false); end
    [~, ~, site_idx_all] = unique(site_data);
else
    [~, ~, site_idx_all] = unique(site_data);
end
if iscell(group_data), group_vec = cell2mat(group_data); else, group_vec = group_data; end
u_sites = unique(site_idx_all); n_sites = length(u_sites);

% 初始检查
[~, p_vec] = match_cal_p(cri_type, val_header, val_cat, ignore_nan);
if isempty(p_vec), min_p = 0; else, min_p = min(p_vec(~isnan(p_vec))); end
if min_p >= target_p, fprintf('Initial data matched (min P = %.4f). No removal.\n', min_p); return; end

ex_id = [];
total_subjects = length(val_header{1});
iter_count = 0;

fprintf('Parallel pool initializing (Greedy)... please wait.\n');

while length(ex_id) < total_subjects - 2
    iter_count = iter_count + 1;

    % 刹车检查
    [vh_curr, vc_curr] = match_exclude(cri_type, val_header, val_cat, ex_id);
    [~, p_vec_curr] = match_cal_p(cri_type, vh_curr, vc_curr, ignore_nan);
    current_min_p = min(p_vec_curr(~isnan(p_vec_curr)));
    if isempty(current_min_p), current_min_p = 0; end
    if current_min_p >= target_p, fprintf('  -> Target reached (min P = %.4f). Stopping.\n', current_min_p); break; end

    % 计算站点计数
    current_counts = zeros(n_sites, 2);
    valid_indices = setdiff(1:total_subjects, ex_id);
    curr_sites = site_idx_all(valid_indices); curr_grps = group_vec(valid_indices);
    for s = 1:n_sites
        sid = u_sites(s); mask = (curr_sites == sid);
        current_counts(s, 1) = sum(curr_grps(mask) == 2);
        current_counts(s, 2) = sum(curr_grps(mask) == 1);
    end

    scores = zeros(total_subjects, 1);
    is_excluded = false(total_subjects, 1); is_excluded(ex_id) = true;

    % 并行计算得分
    parfor j = 1:total_subjects
        score_temp = -Inf;
        if ~is_excluded(j)
            this_sid = site_idx_all(j); this_grp = group_vec(j);
            s_row = find(u_sites == this_sid, 1);
            can_remove = true;
            if this_grp == 2
                if current_counts(s_row, 1) <= min_counts(1), can_remove = false; end
            elseif this_grp == 1
                if current_counts(s_row, 2) <= min_counts(2), can_remove = false; end
            end
            if can_remove
                [vh_t, vc_t] = match_exclude(cri_type, val_header, val_cat, [ex_id, j]);
                score_temp = match_cal_p(cri_type, vh_t, vc_t, ignore_nan);
            end
        end
        scores(j) = score_temp;
    end

    % 贪婪选择：直接选最大值
    [sorted_scores, sorted_idx] = sort(scores, 'descend');
    if sorted_scores(1) == -Inf, fprintf('  -> Locked. Stopping.\n'); break; end

    best_candidates = sorted_idx(1:batch_size);
    if(rem(iter_count, 5) == 0)
        fprintf('Greedy Iter %d: Removed %d. Score=%.4e | Min P=%.4e\n', iter_count, length(best_candidates), sorted_scores(1), current_min_p);
    end
    ex_id = [ex_id, best_candidates'];
end
raw_final(ex_id + 1, :) = [];
end

function [raw_final] = match_annealing(raw_final, cri_type, val_header, val_cat, ignore_nan, site_data, group_data, min_counts, target_p)
% ----------------------------------------------
% 模拟退火 (Simulated Annealing) 实现
% ----------------------------------------------

% [SA 参数配置]
T = 0.5;           % 初始温度 (Temperature)。控制"随机程度"。0.5 是个经验值，既不太高也不太低。
alpha = 0.95;      % 冷却系数 (Cooling Rate)。每次迭代 T = T * alpha。越接近 1 降温越慢，搜索越细致。
% ----------------------------------------------

% 数据预处理 (同 Greedy)
if iscell(site_data)
    if any(cellfun(@isnumeric, site_data)), site_data = cellfun(@(x) char(string(x)), site_data, 'UniformOutput', false); end
    [~, ~, site_idx_all] = unique(site_data);
else
    [~, ~, site_idx_all] = unique(site_data);
end
if iscell(group_data), group_vec = cell2mat(group_data); else, group_vec = group_data; end
u_sites = unique(site_idx_all); n_sites = length(u_sites);

% 初始检查
[~, p_vec] = match_cal_p(cri_type, val_header, val_cat, ignore_nan);
if isempty(p_vec), min_p = 0; else, min_p = min(p_vec(~isnan(p_vec))); end
if min_p >= target_p, fprintf('Initial data matched. No removal.\n'); return; end

ex_id = [];
total_subjects = length(val_header{1});
iter_count = 0;

fprintf('Parallel pool initializing (Annealing)... please wait.\n');

while length(ex_id) < total_subjects - 2
    iter_count = iter_count + 1;

    % 刹车检查
    [vh_curr, vc_curr] = match_exclude(cri_type, val_header, val_cat, ex_id);
    [~, p_vec_curr] = match_cal_p(cri_type, vh_curr, vc_curr, ignore_nan);
    current_min_p = min(p_vec_curr(~isnan(p_vec_curr)));
    if isempty(current_min_p), current_min_p = 0; end
    if current_min_p >= target_p
        fprintf('  -> Target reached (min P = %.4f). Stopping.\n', current_min_p);
        break;
    end

    % 计数逻辑
    current_counts = zeros(n_sites, 2);
    valid_indices = setdiff(1:total_subjects, ex_id);
    curr_sites = site_idx_all(valid_indices); curr_grps = group_vec(valid_indices);
    for s = 1:n_sites
        sid = u_sites(s); mask = (curr_sites == sid);
        current_counts(s, 1) = sum(curr_grps(mask) == 2);
        current_counts(s, 2) = sum(curr_grps(mask) == 1);
    end

    scores = zeros(total_subjects, 1);
    is_excluded = false(total_subjects, 1); is_excluded(ex_id) = true;

    % Parfor 计算每一个人的"移除价值"
    parfor j = 1:total_subjects
        score_temp = -Inf;
        if ~is_excluded(j)
            this_sid = site_idx_all(j); this_grp = group_vec(j);
            s_row = find(u_sites == this_sid, 1);
            can_remove = true;
            if this_grp == 2, if current_counts(s_row, 1) <= min_counts(1), can_remove = false; end
            elseif this_grp == 1, if current_counts(s_row, 2) <= min_counts(2), can_remove = false; end
            end

            if can_remove
                [vh_t, vc_t] = match_exclude(cri_type, val_header, val_cat, [ex_id, j]);
                score_temp = match_cal_p(cri_type, vh_t, vc_t, ignore_nan);
            end
        end
        scores(j) = score_temp;
    end

    % === 模拟退火核心选择逻辑 ===
    valid_mask = scores > -Inf;
    if ~any(valid_mask), break; end

    valid_scores = scores(valid_mask);
    valid_indices_map = find(valid_mask);

    % 1. 归一化得分 (Normalization)
    % 为了让 exp() 计算不溢出且具有物理意义，将分数归一化到 [0, 1] 区间
    max_s = max(valid_scores);
    min_s = min(valid_scores);
    if max_s == min_s
        norm_scores = zeros(size(valid_scores)); % 所有得分相同，概率均等
    else
        norm_scores = (valid_scores - min_s) / (max_s - min_s);
    end

    % 2. 计算 Boltzmann 权重 (Softmax)
    % Probability ~ exp(Score / T)
    weights = exp(norm_scores / T);

    % 3. 概率抽样 (Probabilistic Sampling)
    % randsample 使用权重进行抽样。权重越大，被选中的概率越高。
    % 当 T 很大时，weights 趋向一致 (随机游走)。
    % 当 T 很小时，max score 的 weight 极大 (趋向贪婪)。
    selected_idx_local = randsample(length(weights), 1, true, weights);
    candidate_to_remove = valid_indices_map(selected_idx_local);

    chosen_score = scores(candidate_to_remove);

    if(rem(iter_count, 5) == 0)
        fprintf('SA Iter %d (T=%.3f): Removed 1 sub. Score=%.4e (Max=%.4e) | Min P=%.4e\n', ...
            iter_count, T, chosen_score, max_s, current_min_p);
    end

    ex_id = [ex_id, candidate_to_remove];

    % 4. 降温 (Cooling)
    T = T * alpha;
    % 防止温度过低导致计算溢出，设定一个下限
    if T < 0.001, T = 0.001; end
end
raw_final(ex_id + 1, :) = [];
end

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
    parts = regexp(cri_simp{i}{1}{1}, '^([^:]+):([^:]+)$', 'tokens');
    if isempty(parts), continue; end
    head = strtrim(parts{1}{1}); cond = strtrim(parts{1}{2});
    col = find(strcmp(head, strtrim(header_simp)));
    if isempty(col), fprintf('Warning: Inclusion criteria column "%s" not found. Skipping.\n', head); continue; end
    mask = zeros(size(raw_simp,1)-1,1);
    is_inv = 0; if cond(1)=='~', is_inv=1; cond(1)=[]; end
    vals = raw_simp(2:end, col);
    nums = nan(size(vals));
    for k=1:numel(vals)
        if isnumeric(vals{k}), nums(k)=vals{k}; elseif ischar(vals{k}) || isstring(vals{k}), nums(k)=str2double(vals{k}); end
    end
    if cond(1)=='{'
        conds = regexp(cond(2:end-1), ',', 'split');
        for k=1:length(conds), c_val = strtrim(conds{k}); mask = mask | cellfun(@(x) strcmpi(char(string(x)), c_val), vals); end
    else
        is_le = cond(1)=='['; is_re = cond(end)==']';
        content = cond(2:end-1); bounds = regexp(content, ',', 'split');
        v_left = -inf; v_right = inf;
        if ~isempty(bounds)
            if ~isempty(strtrim(bounds{1})), val = str2double(bounds{1}); if ~isnan(val), v_left = val; end; end
            if length(bounds)>1 && ~isempty(strtrim(bounds{2})), val = str2double(bounds{2}); if ~isnan(val), v_right = val; end; end
        end
        if is_le, m_l = nums >= v_left; else, m_l = nums > v_left; end
        if is_re, m_r = nums <= v_right; else, m_r = nums < v_right; end
        mask = m_l & m_r;
    end
    if is_inv, mask = ~mask; end
    if any(~isnan(nums)), mask(isnan(nums)) = 0; end
    inclu_idx = inclu_idx & mask;
end
end

function [raw_final, ex_idx] = thre_sub_num(raw_inclu, cri_num_HC, cri_num_ASD, site_col, dx_col)
MAX_RATIO = 4; CHECK_SEX_DIV = true; SEX_COL_NAME = 'SEX';
fprintf('   > Filtering Sites (Min Count: [%d, %d] | Max Ratio: 1:%.1f)...\n', cri_num_HC, cri_num_ASD, MAX_RATIO);
header_inclu = raw_inclu(1, :);
site_idx = find(strcmp(strtrim(header_inclu), site_col)); dx_idx = find(strcmp(strtrim(header_inclu), dx_col)); sex_idx = find(strcmp(strtrim(header_inclu), SEX_COL_NAME));
if isempty(site_idx) || isempty(dx_idx), error('Site or Dx column not found in thre_sub_num.'); end
raw_site = raw_inclu(2:end, site_idx); raw_dx = cell2mat(raw_inclu(2:end, dx_idx));
if CHECK_SEX_DIV && ~isempty(sex_idx), raw_sex = raw_inclu(2:end, sex_idx); end
site_unique = unique(raw_site); ex_idx = zeros(size(raw_inclu, 1)-1, 1); dropped_sites = {};
for i = 1:length(site_unique)
    site_name = site_unique{i}; if isnumeric(site_name), site_name = num2str(site_name); end
    idx_tmp = strcmp(site_unique{i}, raw_site); dx_tmp = raw_dx(idx_tmp);
    n_ASD = sum(dx_tmp == 1); n_HC  = sum(dx_tmp == 2);
    is_drop = false; reason = '';
    if (n_ASD < cri_num_ASD) || (n_HC < cri_num_HC), is_drop = true; reason = sprintf('Too few sub (ASD=%d, HC=%d)', n_ASD, n_HC);
    elseif (n_ASD > n_HC * MAX_RATIO) || (n_HC > n_ASD * MAX_RATIO), is_drop = true; reason = sprintf('Imbalanced Ratio (ASD=%d, HC=%d)', n_ASD, n_HC);
    elseif CHECK_SEX_DIV && ~isempty(sex_idx)
        sex_tmp = raw_sex(idx_tmp); if isnumeric(sex_tmp{1}), sex_tmp = cellfun(@num2str, sex_tmp, 'UniformOutput', false); end
        if length(unique(sex_tmp)) < 2, is_drop = true; reason = 'Single Sex'; end
    end
    if is_drop, ex_idx(idx_tmp) = 1; dropped_sites(end+1,:) = {site_name, reason}; end
end
if ~isempty(dropped_sites)
    fprintf('     [Dropped Sites]:\n');
    for k = 1:size(dropped_sites, 1), fprintf('       - %-15s : %s\n', dropped_sites{k,1}, dropped_sites{k,2}); end
end
ex_idx_full = [0; ex_idx]; raw_final = raw_inclu(ex_idx_full == 0, :);
fprintf('     -> %d subjects remained.\n', size(raw_final,1)-1);
end

function [cri_type, val_header, val_cat, cri_header, cri_category, ignore_nan, valid] = parse_match_criteria(raw_data, match_cri)
header = strtrim(raw_data(1,:)); ignore_nan = zeros(length(match_cri), 1); empty_flag = 1;
cri_type = {}; val_header = {}; val_cat = {}; cri_header = {}; cri_category = {};
for i = 1:length(match_cri)
    cri_tmp = match_cri{i}; if(isempty(cri_tmp)), continue; end
    empty_flag = 0; if(cri_tmp(1) == '*'), ignore_nan(i) = 1; cri_tmp(1) = []; end
    [idx_a, idx_p] = regexp(cri_tmp, '^[^:]+'); cri_type{i} = cri_tmp(idx_a:idx_p); cri_tmp(idx_a:idx_p+1) = [];
    [idx_a, idx_p] = regexp(cri_tmp, '^[^~]+'); cri_header{i} = cri_tmp(idx_a:idx_p); cri_tmp(idx_a:idx_p+1) = [];
    val_header{i} = raw_data(2:end, strcmp(header, cri_header{i}));
    if(strcmpi(cri_type{i}, 'f'))
        cri_category{i} = regexp(cri_tmp, '*', 'split'); for j = 1:length(cri_category{i}), val_cat{i}{j} = raw_data(2:end, strcmp(cri_category{i}{j}, header)); end
    else
        cri_category{i} = cri_tmp; val_cat{i} = raw_data(2:end, strcmp(cri_category{i}, header));
    end
end
valid = ~empty_flag;
end

function [p_score, p_sep] = match_cal_p(cri_type, val_header, val_cat, ignore_nan)
p_sep = zeros(length(cri_type), 1);
for i = 1:length(cri_type)
    type_tmp = cri_type{i}; val_header_tmp = val_header{i}; val_cat_tmp = val_cat{i};
    if strcmpi(type_tmp, 't') || strcmpi(type_tmp, 'f')
        v_temp = nan(size(val_header_tmp));
        for k=1:numel(val_header_tmp)
            if isnumeric(val_header_tmp{k}) && ~isempty(val_header_tmp{k}), v_temp(k) = val_header_tmp{k};
            elseif ischar(val_header_tmp{k}), v_temp(k) = str2double(val_header_tmp{k}); end
        end
        val_header_tmp = v_temp;
    end
    if(strcmpi(type_tmp, 't'))
        idx_nan_header = isnan(val_header_tmp); idx_nan_cat = cellfun(@(x) sum(isnan(x))>0 || isempty(x), val_cat_tmp); idx_nan = idx_nan_header | idx_nan_cat;
    elseif(strcmpi(type_tmp, 'f'))
        idx_nan_header = isnan(val_header_tmp); idx_nan_cat = ones(length(val_header_tmp), 1);
        for j = 1:length(val_cat_tmp), idx_nan_cat = idx_nan_cat .* cellfun(@(x) sum(isnan(x))>0 || isempty(x), val_cat_tmp{j}); end
        idx_nan = idx_nan_header | idx_nan_cat;
    elseif(strcmpi(type_tmp, 'x2'))
        idx_nan_header = cellfun(@(x) sum(isnan(x))>0 || isempty(x), val_header_tmp); idx_nan_cat = cellfun(@(x) sum(isnan(x))>0 || isempty(x), val_cat_tmp); idx_nan = idx_nan_header | idx_nan_cat;
    end
    if(sum(idx_nan) > 0)
        if(ignore_nan(i) == 1)
            val_header_tmp(idx_nan) = [];
            if strcmpi(type_tmp, 'f') && iscell(val_cat_tmp), for j=1:length(val_cat_tmp), val_cat_tmp{j}(idx_nan) = []; end
            else, val_cat_tmp(idx_nan) = []; end
        else, error('NaN detected. Use * to ignore.'); end
    end
    try
        if(strcmpi(type_tmp, 't'))
            try [~, ~, cat_tmp_uniqu] = unique(val_cat_tmp); catch, [~, ~, cat_tmp_uniqu] = unique(cell2mat(val_cat_tmp)); end
            if(max(cat_tmp_uniqu) ~= 2), p_sep(i) = 0; else, [~, p_sep(i)] = ttest2(val_header_tmp(cat_tmp_uniqu == 1), val_header_tmp(cat_tmp_uniqu == 2)); end
        elseif(strcmpi(type_tmp, 'f'))
            cat_tmp_uniqu = {}; for j = 1:length(val_cat_tmp), try [~, ~, cat_tmp_uniqu{j}] = unique(val_cat_tmp{j}); catch, [~, ~, cat_tmp_uniqu{j}] = unique(cell2mat(val_cat_tmp{j})); end; end
            if(isscalar(cat_tmp_uniqu)), p_sep(i) = anova1(val_header_tmp, cat_tmp_uniqu{1}, 'off');
            else, p_tmp = anovan(val_header_tmp, cat_tmp_uniqu, 'model', 'interaction', 'display', 'off'); p_sep(i) = p_tmp(3); end
        elseif(strcmpi(type_tmp, 'x2'))
            try [~, ~, header_tmp_uniqu] = unique(val_header_tmp); catch, [~, ~, header_tmp_uniqu] = unique(cell2mat(val_header_tmp)); end
            try [~, ~, cat_tmp_uniqu] = unique(val_cat_tmp); catch, [~, ~, cat_tmp_uniqu] = unique(cell2mat(val_cat_tmp)); end
            [~, ~, p_sep(i)] = crosstab(header_tmp_uniqu, cat_tmp_uniqu);
        end
    catch, p_sep(i) = 0; end
end
valid_p = p_sep(~isnan(p_sep)); valid_p = max(valid_p, realmin);
if isempty(valid_p), p_score = 0; else, p_score = length(valid_p) / sum(1 ./ valid_p); end
end

function [raw_final] = match_random(raw_final, cri_type, val_header, val_cat, ignore_nan, dx_col)
dx_col_idx = find(strcmp(raw_final(1,:), dx_col)); dx = cell2mat(raw_final(2:end, dx_col_idx));
num_ASD = sum(dx == 1); num_HC = sum(dx == 2); diff_num = num_ASD - num_HC;
if(diff_num == 0), fprintf('Groups already balanced. No random removal needed.\n'); return; end
if(diff_num > 0), dx_ex = 1; else, dx_ex = 2; diff_num = abs(diff_num); end
target_indices = find(dx == dx_ex); best_score = -1; ex_id_best = [];
fprintf('Running 10000 random permutations (Harmonic Mean)...\n');
for i = 1:10000
    idx_tmp = randperm(length(target_indices)); to_remove_local = idx_tmp(1:diff_num); ex_idx_g = target_indices(to_remove_local);
    [val_header_tmp, val_cat_tmp] = match_exclude(cri_type, val_header, val_cat, ex_idx_g);
    [score_now, ~] = match_cal_p(cri_type, val_header_tmp, val_cat_tmp, ignore_nan);
    if score_now > best_score, best_score = score_now; ex_id_best = ex_idx_g; end
end
raw_final(ex_id_best + 1, :) = [];
end

function [val_header_out, val_cat_out] = match_exclude(cri_type, val_header, val_cat, ex_id)
val_header_out = val_header; val_cat_out = val_cat;
if isempty(ex_id), return; end
for i = 1:length(val_header), val_header_out{i}(ex_id) = []; end
for i = 1:length(val_cat)
    if(strcmpi(cri_type{i}, 'f'))
        for j = 1:length(val_cat{i}), val_cat_out{i}{j}(ex_id) = []; end
    else, val_cat_out{i}(ex_id) = []; end
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
        else, str_tmp = [str_tmp, cri_category{i}]; end
        str_tmp = [str_tmp, ' : ', num2str(p_sep(i))]; str = [str, str_tmp, '\n'];
    end
end
str = [str, '\nSubjects Number per Site:\n'];
name1 = group_names{1}; name2 = group_names{2};
str = [str, sprintf('                | %-10s %-10s\n', name1, name2)]; str = [str, '--------------------------------------------\n'];
dx_idx = strcmp(raw_final(1,:), dx_col); site_idx = strcmp(raw_final(1,:), site_col);
dx_col_data = raw_final(2:end, dx_idx); SITE_ID = raw_final(2:end, site_idx); [site_uniq, ~, site_idx_num] = unique(SITE_ID);
count_grp1 = @(idx_mask) sum(cellfun(@(x) (ischar(x) && strcmp(x, name1)) || (isnumeric(x) && x==2), dx_col_data(idx_mask)));
count_grp2 = @(idx_mask) sum(cellfun(@(x) (ischar(x) && strcmp(x, name2)) || (isnumeric(x) && x==1), dx_col_data(idx_mask)));
total_grp1 = count_grp1(true(size(dx_col_data))); total_grp2 = count_grp2(true(size(dx_col_data)));
str = [str, sprintf('WHOLE           | %-10d %-10d\n', total_grp1, total_grp2)];
for i = 1:length(site_uniq)
    site_name = site_uniq{i}; if isnumeric(site_name), site_name = num2str(site_name); end
    len_pad = 16 - length(site_name); if len_pad > 0, site_name = [site_name, repmat(' ', 1, len_pad)]; end
    site_mask = (site_idx_num == i); n_g1 = count_grp1(site_mask); n_g2 = count_grp2(site_mask);
    str = [str, sprintf('%s| %-10d %-10d\n', site_name, n_g1, n_g2)];
end
end