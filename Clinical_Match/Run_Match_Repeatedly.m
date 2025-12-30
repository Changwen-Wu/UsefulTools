function [best_raw, best_stats, best_summary] = Run_Match_Repeatedly(n_repeats, pheno_path, ...
    sheet_name, inclu_cri, match_cri, min_counts, site_col_name, dx_col_name, group_names, target_p)
% RUN_MATCH_REPEATEDLY  多重启动优化包装器
%
% 功能：
%   1. 首先运行一次 'Greedy' 算法，作为基准结果。
%   2. 然后重复运行 n_repeats 次 'Annealing' 算法。
%   3. 对比这 (1 + n) 次的结果，输出保留人数最多、统计最平衡的那个结果。
%
% 输入参数：
%   n_repeats : (Integer) 模拟退火重复运行的次数 (建议 5-10 次)。
%   [其他参数] : 与 Clinical_Match 完全一致。
%   注意：输入的 match_method 参数会被本函数忽略，因为本函数强制执行 "1次Greedy + N次Annealing" 的策略。
%
% 输出参数：
%   返回所有运行中表现最好的那一组结果。
% =========================================================================

    fprintf('\n======================================================\n');
    fprintf('   STARTING MULTI-START OPTIMIZATION STRATEGY\n');
    fprintf('   Plan: 1 Greedy Run + %d Annealing Runs\n', n_repeats);
    fprintf('======================================================\n\n');

    % ---------------------------------------------------------
    % 1. 运行基准线：贪婪算法 (Greedy)
    % ---------------------------------------------------------
    fprintf('>>> [Step 1] Running Baseline (Greedy)...\n');
    
    % 强制指定方法为 Greedy
    [g_raw, g_stats, g_str] = Clinical_Match(pheno_path, sheet_name, inclu_cri, match_cri, 'Greedy', min_counts, site_col_name, dx_col_name, group_names, target_p);
    
    % 计算贪婪算法的得分
    [best_count, best_h_score] = evaluate_result(g_raw, g_stats);
    
    % 初始化"当前最佳"为贪婪算法的结果
    best_raw = g_raw;
    best_stats = g_stats;
    best_summary = g_str;
    best_method_source = 'Greedy (Baseline)';
    
    fprintf('    -> Greedy Result: %d subjects | H-Score: %.4e\n\n', best_count, best_h_score);

    % ---------------------------------------------------------
    % 2. 循环运行：模拟退火 (Annealing)
    % ---------------------------------------------------------
    fprintf('>>> [Step 2] Running Annealing Explorations (%d times)...\n', n_repeats);
    
    for i = 1:n_repeats
        fprintf('    -> Annealing Run #%d / %d ... ', i, n_repeats);
        
        % 强制指定方法为 Annealing
        % 注意：为了避免屏幕输出太多干扰信息，这里可以考虑临时屏蔽 Clinical_Match 内部的 fprintf，
        % 但为了监控进度，保留输出也可以，通过换行区分。
        fprintf('\n'); 
        [sa_raw, sa_stats, sa_str] = Clinical_Match(pheno_path, sheet_name, inclu_cri, match_cri, 'Annealing', min_counts, site_col_name, dx_col_name, group_names, target_p);
        
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
            best_count = curr_count;
            best_h_score = curr_h_score;
            best_raw = sa_raw;
            best_stats = sa_stats;
            best_summary = sa_str;
            best_method_source = sprintf('Annealing Run #%d', i);
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
    
    % 在 summary 字符串末尾追加这一信息
    add_info = sprintf('\n[Optimization Info]\nSelected from 1 Greedy + %d Annealing runs.\nSource: %s\n', n_repeats, best_method_source);
    best_summary = [best_summary, add_info];

end

%% ================= 辅助函数：评估结果质量 =================
function [count, h_score] = evaluate_result(raw_data, p_stats)
    % 1. 获取保留的被试总数 (行数 - 表头)
    count = size(raw_data, 1) - 1;
    
    % 2. 计算 H-Score (P值的调和平均数)，用于平局决胜
    % 如果 p_stats.p_sep 存在且有效
    if isfield(p_stats, 'p_sep') && ~isempty(p_stats.p_sep)
        p_vals = p_stats.p_sep;
        % 过滤 NaN 并设定底限防止除零 (和主函数逻辑保持一致)
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