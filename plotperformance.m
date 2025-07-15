% MATLAB Script for Battery Data Visualization

% --- 1. 파일 로드 ---
% 현재 디렉토리에서 .xlsx 파일을 찾습니다.
files = dir('*.xlsx');
if isempty(files)
    error('현재 디렉토리에 XLSX 파일이 없습니다. 파일을 확인해주세요.');
end
filename = files(1).name; % 첫 번째로 발견된 xlsx 파일을 사용합니다.
fprintf('%s 파일을 불러옵니다.\n', filename);

% readtable 함수를 사용하여 데이터를 불러옵니다.
% 'PreserveVariableNames' 옵션을 true로 설정하여 원본 열 이름을 그대로 가져옵니다.
T = readtable(filename, 'PreserveVariableNames', true);


% --- 2. 데이터 파싱 ---
% 데이터의 열 개수와 변수(열) 이름을 가져옵니다.
[~, numCols] = size(T);
colNames = T.Properties.VariableNames;

% 기본 변수는 8개로 가정합니다 (time, Voltage, Current, OCV, CCV, Crate, SOC, Temp)
numVarsPerBattery = 8; 
numBatteries = numCols / numVarsPerBattery;

fprintf('총 %d개의 배터리 데이터 세트를 발견했습니다.\n', numBatteries);

% 각 배터리의 데이터를 구조체(struct)에 저장하여 관리합니다.
batteryData = struct();
for i = 1:numBatteries
    startCol = (i-1) * numVarsPerBattery + 1;
    endCol = i * numVarsPerBattery;
    
    % 각 배터리별로 데이터를 추출합니다.
    % 열 이름이 중복되므로 인덱스를 사용하여 접근합니다.
    tempTable = T(:, startCol:endCol);
    
    % 각 배터리 데이터에 대한 필드 이름을 설정합니다.
    % (예: batteryData(1).Time, batteryData(1).Voltage 등)
    batteryData(i).Time    = tempTable{:, 1};
    batteryData(i).Voltage = tempTable{:, 2};
    batteryData(i).Current = tempTable{:, 3};
    % OCV, CCV, Crate는 이번 분석에 사용하지 않지만, 같은 방식으로 접근 가능합니다.
    % batteryData(i).OCV     = tempTable{:, 4}; 
    % batteryData(i).CCV     = tempTable{:, 5};
    % batteryData(i).Crate   = tempTable{:, 6};
    batteryData(i).SOC     = tempTable{:, 7};
    batteryData(i).Temp    = tempTable{:, 8};
end


% --- 3. 데이터 시각화 (Plotting) ---

%% 플롯 1: 각 배터리별 시간에 따른 전압 및 전류
for i = 1:numBatteries
    figure; % 각 배터리마다 새로운 figure 창을 생성합니다.
    
    yyaxis left; % 왼쪽 y축 활성화
    plot(batteryData(i).Time, batteryData(i).Voltage, 'b-', 'LineWidth', 1.5);
    ylabel('전압 (V)');
    
    yyaxis right; % 오른쪽 y축 활성화
    plot(batteryData(i).Time, batteryData(i).Current, 'r--', 'LineWidth', 1.5);
    ylabel('전류 (A)');
    
    xlabel('시간 (s)');
    title(sprintf('배터리 #%d: 시간에 따른 전압 및 전류', i));
    legend('전압', '전류');
    grid on;
end

%% 플롯 2: 모든 배터리의 시간에 따른 SOC 비교
figure;
hold on; % 여러 데이터를 한 플롯에 겹쳐서 그립니다.
colors = lines(numBatteries); % 배터리 개수만큼 색상을 자동으로 생성합니다.

for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).SOC, 'LineWidth', 1.5, 'Color', colors(i,:), 'DisplayName', sprintf('배터리 #%d', i));
end
hold off;

xlabel('시간 (s)');
ylabel('SOC (%)');
title('시간에 따른 배터리별 SOC 비교');
legend show; % 범례를 표시합니다.
grid on;

%% 플롯 3: 각 배터리별 SOC에 따른 전압 (V-SOC Curve)
figure;
hold on;
colors = lines(numBatteries);

for i = 1:numBatteries
    plot(batteryData(i).SOC, batteryData(i).Voltage, '.', 'MarkerSize', 8, 'Color', colors(i,:), 'DisplayName', sprintf('배터리 #%d', i));
end
hold off;

xlabel('SOC (%)');
ylabel('전압 (V)');
title('SOC에 따른 전압 특성 곡선');
legend show;
grid on;

fprintf('총 3 종류의 플롯 생성을 완료했습니다.\n');