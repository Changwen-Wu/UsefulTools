clear;clc
% --- 1. 筛选标准 (Inclusion Criteria) ---
inclu_cri = {
    'Mean_FD:[,0.5]';
    'Max_Motion:[,3]'
};

input_file = 'ABIDE_Merged_Behavioral_Final.csv'; 
output_file = 'ABIDE_Matched_Final_random_greed1.csv';

match_cri = {
    'T:AGE_AT_SCAN~DX_GROUP';           % 1. 年龄 (T检验)
    'X2:SEX~DX_GROUP';                  % 2. 性别 (卡方)
    'T:Mean_FD~DX_GROUP';               % 3. 平均头动 (T检验)
    '*T:FIQ~DX_GROUP';                  % 4. 全量表智商 (T检验, 忽略缺失)
    '*X2:HANDEDNESS_CATEGORY~DX_GROUP'  % 5. 利手 (卡方, 忽略缺失)
    'X2:SITE_ID~DX_GROUP'               % <--- 【新增】 站点匹配 (核心!)
};

group_names = {'TDC', 'ASD'}; 
min_counts = [5, 5]; 
target_p = 0.15;
site_col = 'SITE_ID';
dx_col   = 'DX_GROUP';


%% 2. 运行 Clinical_Match
fprintf('正在执行筛选与匹配...\n');

% [raw_final, p_stats, summary_report] = Clinical_Match(...
%     input_file, '', ...       
%     inclu_cri, ...            
%     match_cri, ...            
%     'Annealing', ...             
%     min_counts, ...           
%     site_col, ...             
%     dx_col, ...               
%     group_names, ...
%     target_p
% );

[raw_final, p_stats, summary_report] = Run_Match_Repeatedly(...
    5,...
    input_file, '', ...       
    inclu_cri, ...            
    match_cri, ...                       
    min_counts, ...           
    site_col, ...             
    dx_col, ...               
    group_names, ...
    target_p ...
);


%% 3. 保存结果与报告
if ~isempty(raw_final)
    fprintf('\n正在保存匹配后的数据...\n');
    
    T_final = cell2table(raw_final(2:end, :), 'VariableNames', raw_final(1, :));
    writetable(T_final, output_file);
    
    fprintf('成功! 结果已保存至: %s\n', output_file);
    fprintf('最终保留人数: %d\n', height(T_final));
    
else
    fprintf('错误: 匹配后没有剩余被试，请检查筛选条件是否过严。\n');
end

