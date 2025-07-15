% MATLAB Script for Battery Data Visualization (Separated Charge/Discharge Capacity)

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

% --- 2.5. 용량(Capacity) 계산 (★수정된 부분: 충전/방전 분리) ---
fprintf('SOC 변화를 기준으로 충/방전 용량(Ah)을 분리하여 계산합니다...\n');
for i = 1:numBatteries
    % SOC 값의 변화량 계산 (데이터 포인트 간의 차이)
    soc_diff = diff(batteryData(i).SOC);

    % 충전/방전 전류를 분리하여 저장할 벡터 초기화
    charge_current = zeros(size(batteryData(i).Current));
    discharge_current = zeros(size(batteryData(i).Current));
    
    % SOC 변화량에 따라 전류 할당
    % diff는 벡터 길이를 1 줄이므로, k+1 인덱스에 전류값을 할당
    for k = 1:length(soc_diff)
        if soc_diff(k) > 0 % SOC 증가 -> 충전
            % 충전 전류는 음수값을 가지는 경우가 많으므로 절대값 사용
            charge_current(k+1) = abs(batteryData(i).Current(k+1));
        elseif soc_diff(k) < 0 % SOC 감소 -> 방전
            % 방전 전류는 양수값을 가지는 경우가 많지만, 일관성을 위해 절대값 사용
            discharge_current(k+1) = abs(batteryData(i).Current(k+1));
        end
    end
    
    % 분리된 전류를 시간에 대해 누적 적분 (단위: Ampere-seconds)
    charge_capacity_As = cumtrapz(batteryData(i).Time, charge_current);
    discharge_capacity_As = cumtrapz(batteryData(i).Time, discharge_current);
    
    % Ah 단위로 변환 후 구조체에 저장
    batteryData(i).Charge_Capacity_Ah = charge_capacity_As / 3600;
    batteryData(i).Discharge_Capacity_Ah = discharge_capacity_As / 3600;
end
fprintf('용량 계산을 완료했습니다.\n');


% --- 3. 데이터 시각화 (Nature 스타일 적용) ---

% --- 스타일 정의 ---
plotFontStyle = 'Arial';
plotFontSize = 10; 
plotLineWidth = 1.5;
axisLineWidth = 1.2;
colors = [0, 114, 178; 213, 94, 0; 0, 158, 115] / 255; 

%% 플롯 1, 2, 3 (이전과 동일)
% Voltage and Current Plot
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
    ax = gca; ax.FontName = plotFontStyle; ax.FontSize = plotFontSize; ax.LineWidth = axisLineWidth; ax.Box = 'on';
    ax.YAxis(1).Color = 'k'; ax.YAxis(2).Color = 'k'; 
    xlabel('Time (s)');
    title(sprintf('Battery #%d', i), 'FontWeight', 'normal'); 
    if i == numBatteries; legend([p1, p2], {'Voltage', 'Current'}, 'Location', 'best'); end
end
sgtitle('Voltage and Current Profiles', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', plotFontStyle);

% SOC Plot
figure('Color', 'white', 'Name', 'SOC Comparison');
hold on;
for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).SOC, 'LineWidth', plotLineWidth, 'Color', colors(mod(i-1, size(colors,1))+1,:), 'DisplayName', sprintf('Battery #%d', i));
end
hold off;
ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on';
xlabel('Time (s)'); ylabel('State of Charge, SOC (%)'); title('Comparison of SOC over Time', 'FontWeight', 'normal');
legend show;

% V-SOC Plot
figure('Color', 'white', 'Name', 'V-SOC Curve');
hold on;
for i = 1:numBatteries
    plot(batteryData(i).SOC, batteryData(i).Voltage, 'o', 'MarkerSize', 7, 'MarkerEdgeColor', colors(mod(i-1, size(colors,1))+1,:), 'DisplayName', sprintf('Battery #%d', i));
end
hold off;
ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on';
xlabel('State of Charge, SOC (%)'); ylabel('Voltage (V)'); title('Voltage vs. SOC Profile', 'FontWeight', 'normal');
legend show; axis tight;

%% 플롯 4: 시간에 따른 누적 충/방전 용량 비교 (★수정된 플롯)
figure('Color', 'white', 'Name', 'Charge-Discharge Capacity');

% 1. 방전 용량 플롯
subplot(1, 2, 1); % 1x2 그리드의 첫 번째 서브플롯
hold on;
for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).Discharge_Capacity_Ah, ...
        'LineWidth', plotLineWidth, ...
        'Color', colors(mod(i-1, size(colors,1))+1,:), ...
        'DisplayName', sprintf('Battery #%d', i));
end
hold off;
ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on';
xlabel('Time (s)'); ylabel('Cumulative Capacity (Ah)');
title('Discharge Capacity', 'FontWeight', 'normal');
legend show;

% 2. 충전 용량 플롯
subplot(1, 2, 2); % 1x2 그리드의 두 번째 서브플롯
hold on;
for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).Charge_Capacity_Ah, ...
        'LineWidth', plotLineWidth, ...
        'Color', colors(mod(i-1, size(colors,1))+1,:), ...
        'DisplayName', sprintf('Battery #%d', i));
end
hold off;
ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on';
xlabel('Time (s)'); ylabel('Cumulative Capacity (Ah)');
title('Charge Capacity', 'FontWeight', 'normal');
legend show;

% Figure 전체 제목
sgtitle('Cumulative Capacity over Time', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', plotFontStyle);

fprintf('모든 플롯 생성을 완료했습니다.\n');