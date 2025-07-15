% MATLAB Script for Battery Data Visualization (Nature Style)

% --- 1. 파일 로드 ---
% 이 섹션은 이전과 동일합니다.
files = dir('*.xlsx');
if isempty(files)
    error('현재 디렉토리에 XLSX 파일이 없습니다. 파일을 확인해주세요.');
end
filename = files(1).name;
fprintf('%s 파일을 불러옵니다.\n', filename);
T = readtable(filename, 'PreserveVariableNames', true);


% --- 2. 데이터 파싱 ---
% 이 섹션은 이전과 동일합니다.
[~, numCols] = size(T);
colNames = T.Properties.VariableNames;
numVarsPerBattery = 8;
numBatteries = numCols / numVarsPerBattery;

fprintf('총 %d개의 배터리 데이터 세트를 발견했습니다.\n', numBatteries);

batteryData = struct();
for i = 1:numBatteries
    startCol = (i-1) * numVarsPerBattery + 1;
    endCol = i * numVarsPerBattery;
    tempTable = T(:, startCol:endCol);
    
    batteryData(i).Time    = tempTable{:, 1};
    batteryData(i).Voltage = tempTable{:, 2};
    batteryData(i).Current = tempTable{:, 3};
    batteryData(i).SOC     = tempTable{:, 7};
    batteryData(i).Temp    = tempTable{:, 8};
end


% --- 3. 데이터 시각화 (Nature 스타일 적용) ---

% --- 스타일 정의 ---
% 플롯에 일괄적으로 적용할 스타일을 미리 정의합니다.
plotFontStyle = 'Arial';
plotFontSize = 12;
plotLineWidth = 1.5;
axisLineWidth = 1.2;
% 전문적인 느낌을 주는 색상 팔레트 (Blue, Red, Green)
colors = [0, 114, 178; 213, 94, 0; 0, 158, 115] / 255; 

%% 플롯 1: 각 배터리별 시간에 따른 전압 및 전류
for i = 1:numBatteries
    figure('Color', 'white'); % 흰색 배경의 figure 창 생성
    
    yyaxis left;
    p1 = plot(batteryData(i).Time, batteryData(i).Voltage, 'LineWidth', plotLineWidth, 'Color', colors(1,:));
    ylabel('Voltage (V)');
    ylim([min(batteryData(i).Voltage)*0.98, max(batteryData(i).Voltage)*1.02]); % Y축 범위 조절

    yyaxis right;
    p2 = plot(batteryData(i).Time, batteryData(i).Current, '--', 'LineWidth', plotLineWidth, 'Color', colors(2,:));
    ylabel('Current (A)');
    
    % 공통 스타일 적용
    ax = gca; % 현재 활성화된 축(axes)의 핸들을 가져옴
    ax.FontName = plotFontStyle;
    ax.FontSize = plotFontSize;
    ax.LineWidth = axisLineWidth;
    ax.Box = 'on'; % 축 전체에 박스 표시
    ax.YAxis(1).Color = 'k'; % 왼쪽 y축 색상 (검정)
    ax.YAxis(2).Color = 'k'; % 오른쪽 y축 색상 (검정)
    
    xlabel('Time (s)');
    title(sprintf('Battery #%d: Voltage and Current vs. Time', i), 'FontWeight', 'normal');
    legend([p1, p2], {'Voltage', 'Current'}, 'Location', 'best');
end

%% 플롯 2: 모든 배터리의 시간에 따른 SOC 비교
figure('Color', 'white');
hold on;

for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).SOC, ...
        'LineWidth', plotLineWidth, ...
        'Color', colors(i,:), ...
        'DisplayName', sprintf('Battery #%d', i));
end
hold off;

% 공통 스타일 적용
ax = gca;
ax.FontName = plotFontStyle;
ax.FontSize = plotFontSize;
ax.LineWidth = axisLineWidth;
ax.Box = 'on';

xlabel('Time (s)');
ylabel('State of Charge, SOC (%)');
title('Comparison of SOC over Time', 'FontWeight', 'normal');
legend show;

%% 플롯 3: 각 배터리별 SOC에 따른 전압 (V-SOC Curve)
figure('Color', 'white');
hold on;

for i = 1:numBatteries
    plot(batteryData(i).SOC, batteryData(i).Voltage, 'o', ...
        'MarkerSize', 5, ...
        'MarkerEdgeColor', colors(i,:), ...
        'MarkerFaceColor', colors(i,:), ... % 마커 내부를 채울 경우
        'DisplayName', sprintf('Battery #%d', i));
end
hold off;

% 공통 스타일 적용
ax = gca;
ax.FontName = plotFontStyle;
ax.FontSize = plotFontSize;
ax.LineWidth = axisLineWidth;
ax.Box = 'on';

xlabel('State of Charge, SOC (%)');
ylabel('Voltage (V)');
title('Voltage vs. SOC Profile', 'FontWeight', 'normal');
legend show;
axis tight; % 데이터 범위에 맞게 축을 타이트하게 조절

fprintf('Nature 스타일 플롯 생성을 완료했습니다.\n');