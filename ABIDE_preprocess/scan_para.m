function Para = scan_para(site_name)
% scan_para
% 输入: 站点名称 (字符串, 例如 'NYU' 或 'ABIDEII-NYU_1')
% 输出: GRETNA 预处理所需的 Para 结构体
%
% 参考来源: Di Martino et al. (2017) Scientific Data, Table 3.

%% ================== 1. 通用默认参数设置 ==================
Para.DeleteImage.N = 5;  % 删除前 N 帧
Para.Filtering.FreBand = [0.01, 0.08]; % 滤波参数
Para.Normalization.VoxSize = [3, 3, 3]; % 重采样体素大小
Para.Smooth.FWHM = [6, 6, 6]; % 空间平滑
spm_path = fileparts(which('spm'));
Para.Segment.TPM_path = fullfile(spm_path, 'tpm', 'TPM.nii');

% 初始化
Para.SliceTiming.TR = [];
Para.SliceTiming.N = [];
Para.SliceTiming.SliOrd = [];
Para.SliceTiming.RefSlice = [];

switch site_name
    case 'Caltech'
        Para.SliceTiming.TR = 2;
        Para.SliceTiming.N  = 34;
        Para.SliceTiming.SliOrd = [2:2:34,1:2:34];
        Para.Image.NumVols = 150;
    case 'KKI'
        Para.SliceTiming.TR = 2.5;
        Para.SliceTiming.N  = 47;
        Para.SliceTiming.SliOrd = 1:47;
        Para.Image.NumVols = 156;
    case 'Leuven_1'
        Para.SliceTiming.TR = 1.667;
        Para.SliceTiming.N  = 32;
        Para.SliceTiming.SliOrd = 1:32;
        Para.Image.NumVols = 250;
    case 'Leuven_2'
        Para.SliceTiming.TR = 1.667;
        Para.SliceTiming.N  = 32;
        Para.SliceTiming.SliOrd = 1:32;
        Para.Image.NumVols = 250;
    case 'MaxMun_d'
        Para.SliceTiming.TR = 3;
        Para.SliceTiming.N  = 40;
        Para.SliceTiming.SliOrd = [2:2:40,1:2:40];
        Para.Image.NumVols = 200;
    case 'NYU'
        Para.SliceTiming.TR = 2;
        Para.SliceTiming.N  = 33;
        Para.SliceTiming.SliOrd = [1:2:33,2:2,33];
        Para.Image.NumVols = 180;
    case 'OHSU'
        Para.SliceTiming.TR = 2.5;
        Para.SliceTiming.N  = 36;
        Para.SliceTiming.SliOrd = [2:2:36,1:2:36];
        Para.Image.NumVols = 82;
    case 'Olin'
        Para.SliceTiming.TR = 1.5;
        Para.SliceTiming.N  = 29;
        Para.SliceTiming.SliOrd = [1:2:29,2:2,29];
        Para.Image.NumVols = 210;
    case 'Pitt'
        Para.SliceTiming.TR = 1.5;
        Para.SliceTiming.N  = 29;
        Para.SliceTiming.SliOrd = [1:2:29,2:2,29];
        Para.Image.NumVols = 200;
    case 'SDSU' % Interleaved Ascending(GE) odd first
        % see https://cni.su.domains/wiki/index.php?title=GE_Processing
        Para.SliceTiming.TR = 2;
        Para.SliceTiming.N  = 42;
        Para.SliceTiming.SliOrd = [1:2:42,2:2,42];
        Para.Image.NumVols = 180;
    case 'Trinity'
        Para.SliceTiming.TR = 2;
        Para.SliceTiming.N  = 38;
        Para.SliceTiming.SliOrd = 1:38;
        Para.Image.NumVols = 150;
    case 'UCLA_2'
        Para.SliceTiming.TR = 3;
        Para.SliceTiming.N  = 34;
        Para.SliceTiming.SliOrd = [2:2:34,1:2:34];
        Para.Image.NumVols = 120;
    case 'UM_1'
        Para.SliceTiming.TR = 2;
        Para.SliceTiming.N  = 40;
        Para.SliceTiming.SliOrd = 1:40;
        Para.Image.NumVols = 300;
    case 'UM_2'
        Para.SliceTiming.TR = 2;
        Para.SliceTiming.N  = 40;
        Para.SliceTiming.SliOrd = 1:40;
        Para.Image.NumVols = 300;
    case 'USM'
        Para.SliceTiming.TR = 2;
        Para.SliceTiming.N  = 40;
        Para.SliceTiming.SliOrd = [2:2:40,1:2:40];
        Para.Image.NumVols = 240;
    case 'Yale'
        Para.SliceTiming.TR = 2;
        Para.SliceTiming.N  = 34;
        Para.SliceTiming.SliOrd = [2:2:34,1:2:34];
        Para.Image.NumVols = 200;

        %% ============================================================
        %  ABIDE II 站点 (数据来源于 Table 3)
        %  ============================================================

    case 'ABIDEII-BNI_1' % Table 3: TR=3000ms, N=50, SA=A (Ascending)
        Para.SliceTiming.TR = 3.0;
        Para.SliceTiming.N  = 50;
        Para.SliceTiming.SliOrd = 0:0.06:2.94;
        Para.Image.NumVols = 120;

    case 'ABIDEII-EMC_1' % Table 3: TR=2000ms, N=37, SA=ID (Interleaved Descending)
        % GE Scanner.
        Para.SliceTiming.TR = 2.0;
        Para.SliceTiming.N  = 37;
        Para.SliceTiming.SliOrd = [37:-2:1, 36:-2:1];
        Para.SliceTiming.RefSlice = 1; % middle
        Para.Image.NumVols = 160;

    case 'ABIDEII-ETH_1' % Table 3: TR=2000ms, N=40, SA=D (Descending)
        Para.SliceTiming.TR = 2.0;
        Para.SliceTiming.N  = 40;
        Para.SliceTiming.SliOrd = 40:1; % Sequential Descending
        Para.Image.NumVols = 210;

    case 'ABIDEII-GU_1' % Table 3: TR=2000ms, N=43, SA=IA (Interleaved Ascending)
        Para.SliceTiming.TR = 2.0;
        Para.SliceTiming.N  = 43;
        % Siemens, Odd N: 1,3,5...
        Para.SliceTiming.SliOrd = [1:2:43, 2:2:43];
        Para.Image.NumVols = 152;

    case 'ABIDEII-IP_1' % Table 3: TR=2700ms, N=32, SA=A
        Para.SliceTiming.TR = 2.7;
        Para.SliceTiming.N  = 32;
        Para.SliceTiming.SliOrd = 1:32; % Ascending
        Para.Image.NumVols = 85;

    case 'ABIDEII-IU_1' % Table 3: TR=813ms (Multiband?), N=42, SA=IA (Interleaved Ascending)
        % NOTE: Multiband slice timing is complex. If MB factor is 3, 3 slices are acquired simultaneously.
        % Standard slice timing correction may not be appropriate or needs specific JSON file.
        % Here we fill basic info but check your preprocessing pipeline's capability for MB.
        Para.SliceTiming.TR = 0.813;
        Para.SliceTiming.N  = 42;
        Para.SliceTiming.SliOrd = [2:2:42, 1:2:42];
        Para.Image.NumVols = 433;

    case 'ABIDEII-KKI_1' % Table 3: TR=2500ms, N=47, SA=A
        Para.SliceTiming.TR = 2.5;
        Para.SliceTiming.N  = 47;
        Para.SliceTiming.SliOrd = 1:47;
        Para.Image.NumVols = 156;

    case 'ABIDEII-KUL_3' % Table 3: TR=2500ms, N=45, SA=A (Ascending)
        Para.SliceTiming.TR = 2.5;
        Para.SliceTiming.N  = 45;
        Para.SliceTiming.SliOrd = 1:45; % Ascending
        Para.Image.NumVols = 162;

    case 'ABIDEII-NYU_1' % Table 3: TR=2000ms, N=33, SA=IA
        Para.SliceTiming.TR = 2.0;
        Para.SliceTiming.N  = 33;
        Para.SliceTiming.SliOrd = [1:2:33, 2:2:33];
        Para.Image.NumVols = 180;

    case 'ABIDEII-NYU_2' % Table 3: TR=2000ms, N=33, SA=IA
        Para.SliceTiming.TR = 2.0;
        Para.SliceTiming.N  = 34;
        Para.SliceTiming.SliOrd = [2:2:34, 1:2:34];
        Para.Image.NumVols = 180;

    case 'ABIDEII-OHSU_1' % Table 3: TR=2500ms, N=36, SA=IA
        Para.SliceTiming.TR = 2.5;
        Para.SliceTiming.N  = 36;
        Para.SliceTiming.SliOrd = [2:2:36, 1:2:36];
        Para.Image.NumVols = 120;

    case 'ABIDEII-SDSU_1' % Table 3: TR=2000ms, N=42, SA=A
        Para.SliceTiming.TR = 2.0;
        Para.SliceTiming.N  = 42;
        Para.SliceTiming.SliOrd = 1:42;
        Para.Image.NumVols = 180;

    case 'ABIDEII-TCD_1' % Table 3: TR=2000ms, N=37, SA=A [cite: 345]
        Para.SliceTiming.TR = 2.0;
        Para.SliceTiming.N  = 37;
        Para.SliceTiming.SliOrd = 1:37; % Ascending
        Para.Image.NumVols = 210;

    case 'ABIDEII-UCD_1' % Table 3: TR=2000ms, N=36, SA=IA [cite: 345]
        Para.SliceTiming.TR = 2.0;
        Para.SliceTiming.N  = 36;
        % Siemens Even: 2,4,6... then 1,3,5...
        Para.SliceTiming.SliOrd = [2:2:36, 1:2:36];
        Para.Image.NumVols = 151;

    case 'ABIDEII-UCLA_1' % Table 3: TR=3000ms, N=34, SA=IA [cite: 345]
        Para.SliceTiming.TR = 3.0;
        Para.SliceTiming.N  = 34;
        Para.SliceTiming.SliOrd = [2:2:34, 1:2:34]; % Siemens Even: 2,4,6...
        Para.Image.NumVols = 120;

    case 'ABIDEII-UCLA_Long' % Table 3: TR=3000ms, N=34, SA=IA [cite: 345]
        Para.SliceTiming.TR = 3.0;
        Para.SliceTiming.N  = 34;
        Para.SliceTiming.SliOrd = [2:2:34, 1:2:34];    % Siemens Even
        Para.Image.NumVols = 120;

    case 'ABIDEII-U_MIA_1'
        Para.SliceTiming.TR = 2.0;
        Para.SliceTiming.N  = 42;
        Para.SliceTiming.SliOrd = [1:2:42, 2:2:42]; % GE Interleaved Bottom/Up
        Para.Image.NumVols = 295;

    case 'ABIDEII-USM_1' % Table 3: TR=2000ms, N=40, SA=IA [cite: 345]
        Para.SliceTiming.TR = 2.0;
        Para.SliceTiming.N  = 40;
        Para.SliceTiming.SliOrd = [2:2:40, 1:2:40];
        Para.Image.NumVols = 240;

    otherwise
        error('scan_para:UnknownSite', '未定义的站点名称: %s', site_name);
end

Para.SliceTiming.RefSlice = Para.SliceTiming.SliOrd(round(Para.SliceTiming.N/2));

end