function [best_raw, best_stats, best_summary] = Run_Match_Repeatedly(n_repeats, pheno_path, ...
    sheet_name, inclu_cri, match_cri, min_counts, site_col_name, dx_col_name, group_names, target_p)
% RUN_MATCH_REPEATEDLY  多重启动优化包装器 (带剪枝策略)
%
% 功能：
%   1. [Step 0] 预扫描：计算经过硬性筛选后、匹配前的起始人数。
%   2. [Step 1] 基准线：运行 'Greedy' 算法，设定初始的"最大允许剔除人数" (Cutoff)。
%   3. [Step 2] 探索：重复运行 'Annealing' 算法。并将当前的 Best Cutoff 传入。
%      - 如果某次运行剔除的人数超过了 Cutoff，Clinical_Match 会立即返回 9999 (中止)。
%      - 如果发现了更好的结果，Cutoff 会自动收紧，加速后续搜索。
%
% 输入参数：
%   n_repeats : (Integer) 模拟退火重复运行的次数。
%   [其他参数] : 与 Clinical_Match 一致。
% =========================================================================

    fprintf('\n======================================================\n');
    fprintf('   STARTING MULTI-START OPTIMIZATION STRATEGY\n');
    fprintf('   Plan: 1 Greedy Run + %d Annealing Runs\n', n_repeats);
    fprintf('======================================================\n\n');

    % ---------------------------------------------------------
    % 0. 预扫描：获取起始人数 (Start Count)
    % ---------------------------------------------------------
    % 调用 Clinical_Match 使用 'None' 方法，仅做筛选，不匹配。
    % 这样我们可以知道"分母"是多少，从而计算出需要剔除多少人。
    fprintf('>>> [Step 0] Pre-scanning for valid subject pool...\n');
    
    % 注意：传入 Inf 作为 cutoff，防止预处理阶段被意外截断（虽然 None 模式下通常不涉及循环）
    [start_raw, ~, ~] = Clinical_Match(pheno_path, sheet_name, inclu_cri, match_cri, 'None', min_counts, site_col_name, dx_col_name, group_names, target_p, Inf);
    
    start_count = size(start_raw, 1) - 1; % 减去表头
    fprintf('    -> Valid subjects before matching: %d\n\n', start_count);

    % ---------------------------------------------------------
    % 1. 运行基准线：贪婪算法 (Greedy)
    % ---------------------------------------------------------
    fprintf('>>> [Step 1] Running Baseline (Greedy)...\n');
    
    % Greedy 第一次运行，没有历史最佳，所以 cutoff 设为 Inf (不限制)
    [g_raw, g_stats, g_str] = Clinical_Match(pheno_path, sheet_name, inclu_cri, match_cri, 'Greedy', min_counts, site_col_name, dx_col_name, group_names, target_p, Inf);
    
    % 计算贪婪算法的得分
    [best_count, best_h_score] = evaluate_result(g_raw, g_stats);
    
    % 初始化"当前最佳"
    best_raw = g_raw;
    best_stats = g_stats;
    best_summary = g_str;
    best_method_source = 'Greedy (Baseline)';
    
    % [核心逻辑] 计算初始的截断阈值 (Max Iterations / Max Removals)
    % 如果 Greedy 保留了 100 人，起始 150 人，则剔除了 50 人。
    % 下一次 Annealing 如果剔除超过 50 人，就没有意义了。
    current_cutoff = start_count - best_count; 
    
    fprintf('    -> Greedy Result: %d subjects (Removed: %d) | H-Score: %.4e\n', best_count, current_cutoff, best_h_score);
    fprintf('    -> Initial Pruning Cutoff set to: %d removals.\n\n', current_cutoff);

    % ---------------------------------------------------------
    % 2. 循环运行：模拟退火 (Annealing)
    % ---------------------------------------------------------
    fprintf('>>> [Step 2] Running Annealing Explorations (%d times)...\n', n_repeats);
    
    for i = 1:n_repeats
        fprintf('    -> Annealing Run #%d / %d ... ', i, n_repeats);
        
        % [调用核心] 传入 current_cutoff
        % 如果该次运行剔除人数超过 current_cutoff，Clinical_Match 将返回 raw=9999
        fprintf('(Max Cutoff: %d) \n', current_cutoff); 
        
        [sa_raw, sa_stats, sa_str] = Clinical_Match(pheno_path, sheet_name, inclu_cri, match_cri, 'Annealing', min_counts, site_col_name, dx_col_name, group_names, target_p, current_cutoff);
        
        % 检查是否被剪枝 (返回 9999)
        if isscalar(sa_raw) && sa_raw == 9999
            fprintf('       [PRUNED] Exceeded max removals (%d). Skipped.\n', current_cutoff);
            fprintf('    --------------------------------------------\n');
            continue; % 直接跳过本次循环的后续评估
        end

        % 评估当前结果
        [curr_count, curr_h_score] = evaluate_result(sa_raw, sa_stats);
        
        % --- 核心对比逻辑 ---
        is_better = false;
        
        % 标准 1: 人数更多？
        if curr_count > best_count
            is_better = true;
            reason = 'More Subjects';
            
        % 标准 2: 人数一样，但 P 值更均衡 (H-Score更高)？
        elseif curr_count == best_count
            if curr_h_score > best_h_score
                is_better = true;
                reason = 'Better Balance (Tie-breaker)';
            end
        end
        
        if is_better
            fprintf('       [NEW BEST!] %s (Prev: %d, New: %d)\n', reason, best_count, curr_count);
            
            % 更新最佳结果
            best_count = curr_count;
            best_h_score = curr_h_score;
            best_raw = sa_raw;
            best_stats = sa_stats;
            best_summary = sa_str;
            best_method_source = sprintf('Annealing Run #%d', i);
            
            % [核心逻辑] 更新截断阈值
            % 找到了更好的结果（保留更多人），意味着剔除的人更少。
            % 收紧 Cutoff，让后续的运行更快地被剪枝。
            new_cutoff = start_count - best_count;
            if new_cutoff < current_cutoff
                fprintf('       >>> Tightening Pruning Cutoff: %d -> %d\n', current_cutoff, new_cutoff);
                current_cutoff = new_cutoff;
            end
        else
            fprintf('       (Discarded. Count: %d | Score: %.4e)\n', curr_count, curr_h_score);
        end
        fprintf('    --------------------------------------------\n');
    end

    % ---------------------------------------------------------
    % 3. 输出最终总结
    % ---------------------------------------------------------
    fprintf('\n======================================================\n');
    fprintf('   OPTIMIZATION COMPLETED\n');
    fprintf('   Winner Source : %s\n', best_method_source);
    fprintf('   Final Subjects: %d\n', best_count);
    fprintf('   Final H-Score : %.4e\n', best_h_score);
    fprintf('======================================================\n');
    
    % 在 summary 字符串末尾追加优化信息
    add_info = sprintf('\n[Optimization Info]\nSelected from 1 Greedy + %d Annealing runs.\nSource: %s\n', n_repeats, best_method_source);
    best_summary = [best_summary, add_info];
end

%% ================= 辅助函数：评估结果质量 =================
function [count, h_score] = evaluate_result(raw_data, p_stats)
    % 1. 获取保留的被试总数 (行数 - 表头)
    count = size(raw_data, 1) - 1;
    
    % 2. 计算 H-Score (P值的调和平均数)，用于平局决胜
    if isfield(p_stats, 'p_sep') && ~isempty(p_stats.p_sep)
        p_vals = p_stats.p_sep;
        valid_p = p_vals(~isnan(p_vals));
        valid_p = max(valid_p, realmin); 
        
        if isempty(valid_p)
            h_score = 0;
        else
            h_score = length(valid_p) / sum(1 ./ valid_p);
        end
    else
        h_score = 0;
    end
end