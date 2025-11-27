% --- 1. 筛选标准 (Inclusion Criteria) ---
inclu_cri = {
    'AGE:[6,18]';    % 年龄必须 < 18 (开区间，不包含18)
    'GROUP:{1,2}'        % 确保只保留 1(ASD) 和 2(HC) 组
};

% --- 2. 匹配标准 (Matching Criteria) ---
match_cri = {
    'T:AGE~GROUP';     % 匹配年龄 (连续变量用 T)
    % 'F:AGE~GROUP*SITE';
    'X2:SEX~GROUP';
    '*T:FIQ~GROUP';            % 匹配智商 (IQ可能有缺失值，所以加 * 号忽略空值)
    '*X2:HANDEDNESS~GROUP'     % 匹配头动 (假设你的Excel里头动列名叫 func_mean_fd)
};

pheno_path = "E:\Dataset\ABIDE\ABIDE\ABIDE_Subjects_Info.csv";
sheet_name = "ABIDE_Subjects_Info";
match_method = 'Greedy';
min_counts = [5,5];
group_names = {'ASD', 'TDC'};
site_col_name = 'SITE';
dx_col_name = 'GROUP';

match_cri = {
    'T:AGE~GROUP';     % 匹配年龄 (连续变量用 T)
    'F:AGE~GROUP*SITE';
    'X2:SEX~GROUP';
    '*T:FIQ~GROUP';            % 匹配智商 (IQ可能有缺失值，所以加 * 号忽略空值)
    '*X2:HANDEDNESS~GROUP'     % 匹配头动 (假设你的Excel里头动列名叫 func_mean_fd)
};

[raw_final, p_stats, summary_str] = Clinical_Match(pheno_path, sheet_name, inclu_cri, match_cri, match_method, min_counts, site_col_name, dx_col_name, group_names);

save match_within_site.mat raw_final p_stats summary_str

