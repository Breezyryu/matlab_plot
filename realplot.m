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
    figure('Position', [100, 100, 1000, 600]);
    
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
        
        % 매크로 로직에 따른 데이터 처리
        [cycle_02C, capacity_02C, cycle_hybrid, capacity_hybrid] = ...
            processDataWithMacroLogic(cycle_clean, capacity_clean);
        
        % 색상 인덱스
        color_idx = mod(i-1, size(colors, 1)) + 1;
        
        % 0.2C 데이터 플롯 (실선, 원형 마커)
        if ~isempty(cycle_02C)
            plot(cycle_02C, capacity_02C, 'o-', ...
                 'Color', colors(color_idx, :), ...
                 'LineWidth', 1.5, ...
                 'MarkerSize', 6, ...
                 'MarkerFaceColor', 'none', ...
                 'MarkerEdgeColor', colors(color_idx, :), ...
                 'LineStyle', '-', ...
                 'DisplayName', sprintf('Battery %d - 0.2C', i));
        end
        
        % 1.0C+0.5C 하이브리드 데이터 플롯 (점선, 사각형 마커)
        if ~isempty(cycle_hybrid)
            plot(cycle_hybrid, capacity_hybrid, 's--', ...
                 'Color', colors(color_idx, :), ...
                 'LineWidth', 1.5, ...
                 'MarkerSize', 6, ...
                 'MarkerFaceColor', 'none', ...
                 'MarkerEdgeColor', colors(color_idx, :), ...
                 'LineStyle', '--', ...
                 'DisplayName', sprintf('Battery %d - 1.0C+0.5C', i));
        end
    end
    
    % 축 레이블 및 제목 설정 (과학 저널 스타일)
    xlabel('Cycle Number', 'FontSize', 14, 'FontWeight', 'bold');
    ylabel('Capacity (mAh g^{-1})', 'FontSize', 14, 'FontWeight', 'bold');
    title('Cycle Performance: 0.2C vs 1.0C+0.5C Hybrid Discharge', 'FontSize', 16, 'FontWeight', 'bold');
    
    % 범례 설정
    legend('Location', 'best', 'FontSize', 10, 'Box', 'off');
    
    % 격자 설정
    grid on;
    set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.3);
    
    % 축 스타일 설정
    set(gca, 'FontSize', 12, 'LineWidth', 1.2);
    set(gca, 'Box', 'on');
    
    % 여백 조정
    set(gca, 'Position', [0.1, 0.13, 0.85, 0.75]);
    
    % 축 범위 자동 조정
    xlim([0, max(xlim)]);
    ylim([0, max(ylim)]);
    
    hold off;
    
    fprintf('플롯이 완료되었습니다.\n');
    
catch ME
    fprintf('오류가 발생했습니다: %s\n', ME.message);
    fprintf('파일 형식이나 시트 이름을 확인해주세요.\n');
end

% 매크로 로직을 적용한 데이터 처리 함수
function [cycle_02C, capacity_02C, cycle_hybrid, capacity_hybrid] = processDataWithMacroLogic(cycles, capacities)
    % 초기화
    cycle_02C = [];
    capacity_02C = [];
    cycle_hybrid = [];
    capacity_hybrid = [];
    
    i = 1;
    while i <= length(cycles)
        current_cycle = cycles(i);
        current_capacity = capacities(i);
        
        % 매크로 로직: 사이클 차이가 3 미만인 연속 데이터를 찾아서 합산
        if i < length(cycles) - 1
            next_cycle = cycles(i+1);
            third_cycle = cycles(i+2);
            
            % 연속된 3개 사이클의 차이 확인
            if abs(next_cycle - current_cycle) < 3 && abs(third_cycle - next_cycle) < 3
                % 1.0C + 0.5C 하이브리드 패턴 (2번째와 3번째 합치기)
                next_capacity = capacities(i+1);
                third_capacity = capacities(i+2);
                
                % 첫 번째는 0.2C로 처리
                cycle_02C = [cycle_02C; current_cycle];
                capacity_02C = [capacity_02C; current_capacity];
                
                % 두 번째와 세 번째를 합산하여 하이브리드로 처리
                hybrid_cycle = next_cycle;  % 1.0C 사이클 번호 사용
                hybrid_capacity = next_capacity + third_capacity;
                
                cycle_hybrid = [cycle_hybrid; hybrid_cycle];
                capacity_hybrid = [capacity_hybrid; hybrid_capacity];
                
                i = i + 3;  % 3개 처리했으므로 3 증가
            else
                % 일반적인 0.2C 사이클로 처리
                cycle_02C = [cycle_02C; current_cycle];
                capacity_02C = [capacity_02C; current_capacity];
                i = i + 1;
            end
        else
            % 마지막 데이터들
            cycle_02C = [cycle_02C; current_cycle];
            capacity_02C = [capacity_02C; current_capacity];
            i = i + 1;
        end
    end
    
    % 정렬
    if ~isempty(cycle_02C)
        [cycle_02C, sort_idx] = sort(cycle_02C);
        capacity_02C = capacity_02C(sort_idx);
    end
    
    if ~isempty(cycle_hybrid)
        [cycle_hybrid, sort_idx] = sort(cycle_hybrid);
        capacity_hybrid = capacity_hybrid(sort_idx);
    end
end