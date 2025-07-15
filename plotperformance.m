% MATLAB Script for Battery Data Visualization (Nature Style - Hollow Markers)

% --- 1. 파일 로드 ---
files = dir('*.xlsx');
if isempty(files)
    error('현재 디렉토리에 XLSX 파일이 없습니다. 파일을 확인해주세요.');
end
filename = files(1).name;
fprintf('%s 파일을 불러옵니다.\n', filename);
T = readtable(filename, 'PreserveVariableNames', true);


% --- 2. 데이터 파싱 ---
[~, numCols] = size(T);
numVarsPerBattery = 8;
numBatteries = numCols / numVarsPerBattery;

fprintf('총 %d개의 배터리 데이터 세트를 발견했습니다.\n', numBatteries);

batteryData = struct();
for i = 1:numBatteries
    startCol = (i-1) * numVarsPerBattery + 1;
    tempTable = T(:, startCol:(startCol+7));
    
    batteryData(i).Time    = tempTable{:, 1};
    batteryData(i).Voltage = tempTable{:, 2};
    batteryData(i).Current = tempTable{:, 3};
    batteryData(i).SOC     = tempTable{:, 7};
    batteryData(i).Temp    = tempTable{:, 8};
end


% --- 3. 데이터 시각화 (Nature 스타일 적용) ---

% --- 스타일 정의 ---
plotFontStyle = 'Arial';
plotFontSize = 10; 
plotLineWidth = 1.5;
axisLineWidth = 1.2;
colors = [0, 114, 178; 213, 94, 0; 0, 158, 115] / 255; 

%% 플롯 1: 각 배터리별 시간에 따른 전압 및 전류 (한 Figure 안에 표시)
figure('Color', 'white', 'Name', 'Voltage and Current Analysis'); 
numRows = ceil(numBatteries / 2);
numCols = 2;

for i = 1:numBatteries
    subplot(numRows, numCols, i); 
    
    yyaxis left;
    p1 = plot(batteryData(i).Time, batteryData(i).Voltage, 'LineWidth', plotLineWidth, 'Color', colors(1,:));
    ylabel('Voltage (V)');
    
    yyaxis right;
    p2 = plot(batteryData(i).Time, batteryData(i).Current, '--', 'LineWidth', plotLineWidth, 'Color', colors(2,:));
    ylabel('Current (A)');
    
    ax = gca;
    ax.FontName = plotFontStyle;
    ax.FontSize = plotFontSize;
    ax.LineWidth = axisLineWidth;
    ax.Box = 'on';
    ax.YAxis(1).Color = 'k'; 
    ax.YAxis(2).Color = 'k'; 
    
    xlabel('Time (s)');
    title(sprintf('Battery #%d', i), 'FontWeight', 'normal'); 
    
    if i == numBatteries
        legend([p1, p2], {'Voltage', 'Current'}, 'Location', 'best');
    end
end
sgtitle('Voltage and Current Profiles for All Batteries', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', plotFontStyle);


%% 플롯 2: 모든 배터리의 시간에 따른 SOC 비교
figure('Color', 'white', 'Name', 'SOC Comparison');
hold on;
for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).SOC, ...
        'LineWidth', plotLineWidth, 'Color', colors(mod(i-1, size(colors,1))+1,:), ...
        'DisplayName', sprintf('Battery #%d', i));
end
hold off;
ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on';
xlabel('Time (s)'); ylabel('State of Charge, SOC (%)'); title('Comparison of SOC over Time', 'FontWeight', 'normal');
legend show;

%% 플롯 3: 각 배터리별 SOC에 따른 전압 (V-SOC Curve) (★수정된 부분)
figure('Color', 'white', 'Name', 'V-SOC Curve');
hold on;
for i = 1:numBatteries
    plot(batteryData(i).SOC, batteryData(i).Voltage, 'o', ... % 마커 스타일: 원
        'MarkerSize', 7, ...                                  % 마커 크기
        'MarkerEdgeColor', colors(mod(i-1, size(colors,1))+1,:), ... % ★마커 테두리 색상 지정
        'DisplayName', sprintf('Battery #%d', i));
        % 'MarkerFaceColor' 속성을 제거하여 내부를 비움
end
hold off;

% 공통 스타일 적용
ax = gca; 
ax.FontName = plotFontStyle; 
ax.FontSize = 12; 
ax.LineWidth = axisLineWidth; 
ax.Box = 'on';
xlabel('State of Charge, SOC (%)'); 
ylabel('Voltage (V)'); 
title('Voltage vs. SOC Profile', 'FontWeight', 'normal');
legend show; 
axis tight;

fprintf('모든 플롯 생성을 완료했습니다. (Plot 3 마커 내부 비움)\n');