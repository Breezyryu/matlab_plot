% 파일 경로 입력받기
file_path = input('Excel 파일 경로를 입력하세요 (예: C:\data\battery_data.xlsx): ', 's');

% 파일 존재 여부 확인
if ~exist(file_path, 'file')
    error('파일을 찾을 수 없습니다: %s', file_path);
end

try
    % Excel 파일에서 "Plot Base Data" 시트 읽기
    [~, ~, raw_data] = xlsread(file_path, 'Plot Base Data');
    
    % 3행부터 데이터 추출 (헤더 제외)
    data = raw_data(3:end, :);
    
    % 열 개수 확인 (2*n개 열)
    num_cols = size(data, 2);
    num_experiments = num_cols / 2;
    
    fprintf('총 %d개의 실험 데이터가 발견되었습니다.\n', num_experiments);
    
    % Scientific journal 스타일 설정
    figure('Position', [100, 100, 800, 600]);
    
    % 색상 팔레트 (과학 저널 스타일)
    colors = [
        0.0000, 0.4470, 0.7410;  % 파란색
        0.8500, 0.3250, 0.0980;  % 주황색
        0.9290, 0.6940, 0.1250;  % 노란색
        0.4940, 0.1840, 0.5560;  % 보라색
        0.4660, 0.6740, 0.1880;  % 녹색
        0.3010, 0.7450, 0.9330;  % 하늘색
        0.6350, 0.0780, 0.1840;  % 빨간색
    ];
    
    % 각 실험별 데이터 플롯
    hold on;
    
    for i = 1:num_experiments
        cycle_col = 2*i - 1;  % 사이클 열
        capacity_col = 2*i;   % 용량 열
        
        % 각 열에서 NaN이 아닌 데이터만 추출
        cycle_data = cell2mat(data(:, cycle_col));
        capacity_data = cell2mat(data(:, capacity_col));
        
        % NaN 값 제거
        valid_idx = ~isnan(cycle_data) & ~isnan(capacity_data);
        cycle_clean = cycle_data(valid_idx);
        capacity_clean = capacity_data(valid_idx);
        
        % 플롯 (선 두께와 마커 크기 조정)
        color_idx = mod(i-1, size(colors, 1)) + 1;
        plot(cycle_clean, capacity_clean, 'o-', ...
             'Color', colors(color_idx, :), ...
             'LineWidth', 1.5, ...
             'MarkerSize', 6, ...
             'MarkerFaceColor', colors(color_idx, :), ...
             'MarkerEdgeColor', colors(color_idx, :), ...
             'DisplayName', sprintf('Battery %d', i));
    end
    
    % 축 레이블 및 제목 설정 (과학 저널 스타일)
    xlabel('Cycle Number', 'FontSize', 14, 'FontWeight', 'bold');
    ylabel('Capacity (mAh g^{-1})', 'FontSize', 14, 'FontWeight', 'bold');
    title('Cycle Performance of Battery Cells', 'FontSize', 16, 'FontWeight', 'bold');
    
    % 범례 설정
    legend('Location', 'best', 'FontSize', 12, 'Box', 'off');
    
    % 격자 설정
    grid on;
    set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.3);
    
    % 축 스타일 설정
    set(gca, 'FontSize', 12, 'LineWidth', 1.2);
    set(gca, 'Box', 'on');
    
    % 여백 조정
    set(gca, 'Position', [0.13, 0.13, 0.82, 0.75]);
    
    % 축 범위 자동 조정
    xlim([0, max(xlim)]);
    ylim([0, max(ylim)]);
    
    hold off;
    
    fprintf('플롯이 완료되었습니다.\n');
    
catch ME
    fprintf('오류가 발생했습니다: %s\n', ME.message);
    fprintf('파일 형식이나 시트 이름을 확인해주세요.\n');
end