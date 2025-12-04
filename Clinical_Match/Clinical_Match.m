function [raw_final, p_stats, summary_str] = Clinical_Match(pheno_path, sheet_name, inclu_cri, match_cri, match_method, min_counts, site_col_name, dx_col_name, group_names)
% CLINICAL_MATCH  通用临床研究被试筛选与自动化匹配工具
%
% 功能概述：
%   读取 Excel/CSV 表型数据，根据预设条件进行硬性筛选（Inclusion Criteria），
%   并利用 贪婪算法(Greedy) 或 随机算法(Random) 自动迭代剔除被试，
%   以实现两组（如 ASD vs HC）在指定协变量（如年龄、性别、站点、IQ）上的统计学平衡。
%
% =========================================================================
% 【算法核心逻辑 (Algorithm Logic)】
%
%   1. 自动编码 (Auto-Encoding):
%      - 函数会自动扫描 Excel 中的文本列（如性别 'F'/'M'，站点 'NYU'），
%      - 在计算前将其转换为内部数字 ID，防止统计函数报错，计算结束后自动还原。
%
%   2. 贪婪算法优化目标 (Optimization Function):
%      - 使用 **调和平均数 (Harmonic Mean)** 作为评分标准。
%      - 公式: Score = N / sum(1 ./ P_values)
%      - 原理: 调和平均数对极小值（短板）非常敏感。这迫使算法优先剔除那些导致
%        某项指标 P 值过低（差异显著）的被试，确保所有协变量均衡，无短板。
%
%   3. 自动刹车 (Braking Mechanism):
%      - 当所有指标的 P 值均大于目标阈值（默认 target_p = 0.15）时，算法会自动停止。
%      - 目的: 防止过度剔除数据，最大程度保留样本量。
%
%   4. 加速机制 (Speed Up):
%      - 默认每次剔除 1 个被试（batch_size = 1），精度最高但速度较慢。
%      - 若样本量巨大（如 >2000），可在代码内部将 `match_greedy` 中的 `batch_size`
%        调整为 5 或 10，可显著提升运行速度。
%
% =========================================================================
% 输入参数 (INPUTS):
%
%   1. pheno_path (String):
%      数据文件路径 (支持 .xlsx, .csv)。例如: 'D:\Data\Participants.csv'
%      
%   2. sheet_name (String):
%      Excel 表单名称。如果是 CSV 文件，可留空 ''。
%
%   3. inclu_cri (Cell Array of Strings) - 【硬性筛选标准】:
%      在匹配前执行的数据清洗规则。支持集合、数值范围和反向剔除。
%      语法规则: '列名:条件'
%      ------------------------------------------------------------
%      符号       | 含义              | 示例
%      ------------------------------------------------------------
%      {A,B}      | 集合 (只选...)     | 'SITE:{NYU, UCLA}' (只保留NYU和UCLA)
%      ~          | 排除 (不要...)     | 'SITE:~{Caltech}'  (剔除Caltech)
%      [min, max] | 闭区间 (含边界)    | 'AGE:[18, 60]'
%      (min, max) | 开区间 (不含边界)  | 'FIQ:(80, 120)'
%      [min, )    | 单侧区间           | 'AGE:[18, )'
%      ------------------------------------------------------------
%
%   4. match_cri (Cell Array of Strings) - 【统计匹配标准】:
%      定义需要平衡的指标。目标是让这些指标的组间差异 P > 0.15。
%      语法规则: '[*]检验方法:变量名~分组变量'
%      ------------------------------------------------------------
%      前缀   | 含义           | 适用场景 & 示例
%      ------------------------------------------------------------
%      T:     | T检验          | 连续变量。如: 'T:AGE~GROUP'
%      X2:    | 卡方检验       | 分类变量。如: 'X2:SEX~GROUP'
%      F:     | ANOVA/交互     | 交互效应。如: 'F:AGE~GROUP*SITE'
%      * | 忽略缺失值     | 前缀。如: '*T:FIQ~GROUP' (忽略无IQ的被试)
%      ------------------------------------------------------------
%
%   5. match_method (String):
%      - 'Greedy': 贪婪算法 (推荐)。智能剔除，保留最多样本，效果最稳健。
%      - 'Random': 随机算法。随机抽样 10000 次，速度快但结果随机。
%      - 'None'  : 不进行匹配，仅执行筛选。
%
%   6. min_counts (Vector):
%      [组1最少人数, 组2最少人数]。例如 [5, 5]。
%      若某站点在筛选后，某一组人数少于此阈值，该站点的所有数据将被剔除。
%
%   7. site_col_name (String):
%      数据中代表"站点/中心"的列名。例如 'SITE_ID' 或 'Site'。
%
%   8. dx_col_name (String):
%      数据中代表"诊断分组"的列名。例如 'DX_GROUP' 或 'Diagnosis'。
%
%   9. group_names (Cell Array of Strings):
%      对应 min_counts 顺序的组名文本标签。用于自动识别和还原数据。
%      【对应关系】：
%      min_counts  = [ 数量1(对照), 数量2(病人) ]
%      group_names = { 'Control',   'Patient'   }
%
% =========================================================================
% 输出参数 (OUTPUTS):
%   raw_final   : (Cell Array) 匹配后的最终数据表（包含表头）。
%   p_stats     : (Struct) 包含最终的统计 P 值。
%   summary_str : (String) 格式化的文本报告，包含各站点人数及最终 P 值。
%
% =========================================================================
% 使用示例 (EXAMPLE):
%
%   % 1. 定义筛选: 只保留男性，年龄 < 30，只保留 ASD 和 TDC 组
%   inclu = { 'SEX:{M}'; 'AGE_AT_SCAN:(,30)'; 'GROUP:{ASD, TDC}' };
%
%   % 2. 定义匹配: 年龄(T检验), 性别(卡方), 站点(卡方,忽略空值), IQ(T检验,忽略空值)
%   match = { 'T:AGE_AT_SCAN~GROUP'; 'X2:SEX~GROUP'; '*X2:SITE~GROUP'; '*T:FIQ~GROUP' };
%
%   % 3. 定义组名: TDC 为对照(逻辑位2), ASD 为病人(逻辑位1)
%   groups = {'TDC', 'ASD'};
%
%   % 4. 运行
%   [data, stats, report] = Clinical_Match('MyData.csv', '', ...
%       inclu, match, 'Greedy', [10, 10], 'SITE', 'GROUP', groups);
%
%   disp(report);
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

header = strtrim(raw(1,:)); % 去除表头空格
raw(1,:) = header;          % 更新回去

% 清理空的筛选标准
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

% 简单检查
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
        if strcmpi(match_method, 'greedy')
            s_idx = find(strcmp(header, site_col_name));
            g_idx = find(strcmp(header, dx_col_name));
            
            site_data = raw_final(2:end, s_idx);
            group_data = raw_final(2:end, g_idx);
            
            % 调用修改后的 greedy 函数
            [raw_final] = match_greedy(raw_final, cri_type, val_header, val_cat, ignore_nan, site_data, group_data, min_counts);
            
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

%% ================== Helper Functions ==================

function [raw_final] = match_greedy(raw_final, cri_type, val_header, val_cat, ignore_nan, site_data, group_data, min_counts)
    % ----------------------------------------------
    % [配置区]
    target_p = 0.15;   % 刹车阈值
    batch_size = 1;    % 每次剔除人数。Parfor 模式下，保持 1 精度最高，且因为并行计算，速度依然很快。
    % ----------------------------------------------
    
    % --- 0. 准备站点和分组数据 ---
    % 统一站点格式
    if iscell(site_data)
        if any(cellfun(@isnumeric, site_data))
             site_data = cellfun(@(x) char(string(x)), site_data, 'UniformOutput', false);
        end
        [~, ~, site_idx_all] = unique(site_data);
    else
        [~, ~, site_idx_all] = unique(site_data);
    end
    
    % 统一分组格式
    if iscell(group_data), group_vec = cell2mat(group_data); else, group_vec = group_data; end
    
    u_sites = unique(site_idx_all);
    n_sites = length(u_sites);
    
    % --- 1. 初始检查 ---
    [~, p_vec] = match_cal_p(cri_type, val_header, val_cat, ignore_nan);
    if isempty(p_vec), min_p = 0; else, min_p = min(p_vec(~isnan(p_vec))); end
    
    if min_p >= target_p
        fprintf('Initial data matched (min P = %.4f). No removal.\n', min_p);
        return;
    end
    
    ex_id = [];
    total_subjects = length(val_header{1});
    iter_count = 0;
    
    fprintf('Parallel pool initializing (if not already started)... please wait.\n');
    
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
        
        % 2. 预计算各站点当前人数
        current_counts = zeros(n_sites, 2); % [Site, Group]
        valid_indices = setdiff(1:total_subjects, ex_id);
        
        % 向量化计算当前各站点人数，避免循环
        curr_sites = site_idx_all(valid_indices);
        curr_grps = group_vec(valid_indices);
        
        for s = 1:n_sites
            sid = u_sites(s);
            mask = (curr_sites == sid);
            g_vals = curr_grps(mask);
            current_counts(s, 1) = sum(g_vals == 2); % HC (G1)
            current_counts(s, 2) = sum(g_vals == 1); % ASD (G2)
        end
        
        % 3. 准备 Parfor 变量
        scores = zeros(total_subjects, 1); % 预分配输出变量
        
        % 创建逻辑掩码用于快速跳过已删除被试 (替代 ex_id 查找)
        is_excluded = false(total_subjects, 1);
        is_excluded(ex_id) = true;
        
        % 4. 并行计算循环 (PARFOR)
        % 注意：parfor 内部不能修改外部变量，所有输入变量作为 broadcast 传入
        parfor j = 1:total_subjects
            score_temp = -Inf; % 默认分数为负无穷
            
            if ~is_excluded(j)
                % --- [实时红线检查] ---
                this_sid = site_idx_all(j);
                this_grp = group_vec(j); % 1=ASD, 2=HC
                
                % 查找站点索引
                % 注意：u_sites 很小，find 在此处开销可接受
                s_row = find(u_sites == this_sid, 1); 
                
                can_remove = true;
                if this_grp == 2 % HC
                    if current_counts(s_row, 1) <= min_counts(1)
                        can_remove = false;
                    end
                elseif this_grp == 1 % ASD
                    if current_counts(s_row, 2) <= min_counts(2)
                        can_remove = false;
                    end
                end
                
                % 如果可以移除，则计算移除后的得分
                if can_remove
                    ex_id_temp = [ex_id, j]; % ex_id 是广播变量
                    [vh_t, vc_t] = match_exclude(cri_type, val_header, val_cat, ex_id_temp);
                    score_temp = match_cal_p(cri_type, vh_t, vc_t, ignore_nan);
                end
            end
            
            scores(j) = score_temp; % 必须对 sliced variable 赋值
        end
        
        % 5. 选出得分最高的人
        [sorted_scores, sorted_idx] = sort(scores, 'descend');
        
        valid_candidates_mask = sorted_scores > -Inf;
        if ~any(valid_candidates_mask)
            fprintf('  -> All remaining subjects are locked by Min Counts. Stopping.\n');
            break; 
        end
        
        num_to_pick = min(batch_size, sum(valid_candidates_mask));
        best_candidates = sorted_idx(1:num_to_pick);
        best_score = sorted_scores(1);
        
        if(rem(iter_count, 1) == 0) 
            fprintf('Greedy (Parfor) Iter %d: Removing %d subjects. Best H-Score=%.4f | Min P=%.4f\n', ...
                iter_count, length(best_candidates), best_score, current_min_p);
        end
        
        ex_id = [ex_id, best_candidates']; 
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
        
        head = strtrim(parts{1}{1}); 
        cond = strtrim(parts{1}{2}); 
        
        col = find(strcmp(head, strtrim(header_simp)));
        if isempty(col)
            fprintf('Warning: Inclusion criteria column "%s" not found. Skipping.\n', head);
            continue;
        end
        
        mask = zeros(size(raw_simp,1)-1,1);
        is_inv = 0; if cond(1)=='~', is_inv=1; cond(1)=[]; end
        
        vals = raw_simp(2:end, col);
        nums = nan(size(vals));
        for k=1:numel(vals)
            if isnumeric(vals{k}), nums(k)=vals{k};
            elseif ischar(vals{k}) || isstring(vals{k}), nums(k)=str2double(vals{k}); end
        end
        
        if cond(1)=='{'
            conds = regexp(cond(2:end-1), ',', 'split');
            for k=1:length(conds)
                c_val = strtrim(conds{k});
                mask = mask | cellfun(@(x) strcmpi(char(string(x)), c_val), vals);
            end
        else
            is_le = cond(1)=='['; is_re = cond(end)==']';
            content = cond(2:end-1); 
            bounds = regexp(content, ',', 'split');
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
        
        if strcmpi(type_tmp, 't') || strcmpi(type_tmp, 'f')
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
        
        if(sum(idx_nan) > 0)
            if(ignore_nan(i) == 1)
                val_header_tmp(idx_nan) = [];
                if strcmpi(type_tmp, 'f') && iscell(val_cat_tmp)
                    for j=1:length(val_cat_tmp), val_cat_tmp{j}(idx_nan) = []; end
                else
                     val_cat_tmp(idx_nan) = [];
                end
            else
                error('NaN detected. Use * to ignore.');
            end
        end
        
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
    
    valid_p = p_sep(~isnan(p_sep));
    valid_p = max(valid_p, 1e-10);
    
    if isempty(valid_p)
        p_score = 0;
    else
        p_score = length(valid_p) / sum(1 ./ valid_p);
    end
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
        [score_now, ~] = match_cal_p(cri_type, val_header_tmp, val_cat_tmp, ignore_nan);
        
        if score_now > best_score
            best_score = score_now;
            ex_id_best = ex_idx_g;
        end
    end
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
dx_col_data = raw_final(2:end, dx_idx);
SITE_ID = raw_final(2:end, site_idx);
[site_uniq, ~, site_idx_num] = unique(SITE_ID);

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