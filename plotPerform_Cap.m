% MATLAB Script for Battery Data Visualization (Improved Capacity Logic)

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

% --- 2.5. 용량(Capacity) 계산 (★개선된 로직) ---
fprintf('SOC 증가/감소 상태를 추적하여 충/방전 용량을 계산합니다...\n');
for i = 1:numBatteries
    % 결과를 저장할 벡터 초기화
    charge_capacity_Ah = zeros(size(batteryData(i).Time));
    discharge_capacity_Ah = zeros(size(batteryData(i).Time));
    
    % 루프를 통해 각 시점의 용량을 계산 (두 번째 데이터 포인트부터 시작)
    for k = 2:length(batteryData(i).Time)
        % 이전 시점의 누적 용량을 가져옴
        prev_charge_cap = charge_capacity_Ah(k-1);
        prev_discharge_cap = discharge_capacity_Ah(k-1);
        
        % 현재 상태 판별 (SOC 증가/감소)
        if batteryData(i).SOC(k) > batteryData(i).SOC(k-1) % 충전 상태
            % 현재 스텝의 시간 간격 (dt)
            dt_seconds = batteryData(i).Time(k) - batteryData(i).Time(k-1);
            % 현재 스텝의 평균 전류 (사다리꼴 적분 원리)
            avg_current = (abs(batteryData(i).Current(k)) + abs(batteryData(i).Current(k-1))) / 2;
            % 현재 스텝에서 충전된 용량 (Ah)
            step_capacity_Ah = (avg_current * dt_seconds) / 3600;
            
            % 충전 용량은 누적하고, 방전 용량은 이전 값을 유지
            charge_capacity_Ah(k) = prev_charge_cap + step_capacity_Ah;
            discharge_capacity_Ah(k) = prev_discharge_cap;
            
        elseif batteryData(i).SOC(k) < batteryData(i).SOC(k-1) % 방전 상태
            dt_seconds = batteryData(i).Time(k) - batteryData(i).Time(k-1);
            avg_current = (abs(batteryData(i).Current(k)) + abs(batteryData(i).Current(k-1))) / 2;
            step_capacity_Ah = (avg_current * dt_seconds) / 3600;
            
            % 방전 용량은 누적하고, 충전 용량은 이전 값을 유지
            discharge_capacity_Ah(k) = prev_discharge_cap + step_capacity_Ah;
            charge_capacity_Ah(k) = prev_charge_cap;
            
        else % SOC 변화 없음 (휴지 상태)
            % 충전, 방전 용량 모두 이전 값을 유지
            charge_capacity_Ah(k) = prev_charge_cap;
            discharge_capacity_Ah(k) = prev_discharge_cap;
        end
    end
    
    % 계산된 결과를 구조체에 저장
    batteryData(i).Charge_Capacity_Ah = charge_capacity_Ah;
    batteryData(i).Discharge_Capacity_Ah = discharge_capacity_Ah;
end
fprintf('용량 계산을 완료했습니다.\n');


% --- 3. 데이터 시각화 (Nature 스타일 적용) ---
% 스타일 정의 및 플롯 코드는 이전과 동일합니다.
plotFontStyle = 'Arial';
plotFontSize = 10; 
plotLineWidth = 1.5;
axisLineWidth = 1.2;
colors = [0, 114, 178; 213, 94, 0; 0, 158, 115] / 255; 

% 플롯 1: 전압 및 전류
figure('Color', 'white', 'Name', 'Voltage and Current Analysis'); 
numRows = ceil(numBatteries / 2); numCols = 2;
for i = 1:numBatteries
    subplot(numRows, numCols, i); 
    yyaxis left; p1 = plot(batteryData(i).Time, batteryData(i).Voltage, 'LineWidth', plotLineWidth, 'Color', colors(1,:)); ylabel('Voltage (V)');
    yyaxis right; p2 = plot(batteryData(i).Time, batteryData(i).Current, '--', 'LineWidth', plotLineWidth, 'Color', colors(2,:)); ylabel('Current (A)');
    ax = gca; ax.FontName = plotFontStyle; ax.FontSize = plotFontSize; ax.LineWidth = axisLineWidth; ax.Box = 'on';
    ax.YAxis(1).Color = 'k'; ax.YAxis(2).Color = 'k'; 
    xlabel('Time (s)'); title(sprintf('Battery #%d', i), 'FontWeight', 'normal'); 
    if i == numBatteries; legend([p1, p2], {'Voltage', 'Current'}, 'Location', 'best'); end
end
sgtitle('Voltage and Current Profiles', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', plotFontStyle);

% 플롯 2: SOC
figure('Color', 'white', 'Name', 'SOC Comparison');
hold on;
for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).SOC, 'LineWidth', plotLineWidth, 'Color', colors(mod(i-1, size(colors,1))+1,:), 'DisplayName', sprintf('Battery #%d', i));
end
hold off;
ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on';
xlabel('Time (s)'); ylabel('State of Charge, SOC (%)'); title('Comparison of SOC over Time', 'FontWeight', 'normal');
legend show;

% 플롯 3: V-SOC
figure('Color', 'white', 'Name', 'V-SOC Curve');
hold on;
for i = 1:numBatteries
    plot(batteryData(i).SOC, batteryData(i).Voltage, 'o', 'MarkerSize', 7, 'MarkerEdgeColor', colors(mod(i-1, size(colors,1))+1,:), 'DisplayName', sprintf('Battery #%d', i));
end
hold off;
ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on';
xlabel('State of Charge, SOC (%)'); ylabel('Voltage (V)'); title('Voltage vs. SOC Profile', 'FontWeight', 'normal');
legend show; axis tight;

% 플롯 4: 충/방전 용량
figure('Color', 'white', 'Name', 'Charge-Discharge Capacity');
subplot(1, 2, 1);
hold on;
for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).Discharge_Capacity_Ah, 'LineWidth', plotLineWidth, 'Color', colors(mod(i-1, size(colors,1))+1,:), 'DisplayName', sprintf('Battery #%d', i));
end
hold off;
ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on';
xlabel('Time (s)'); ylabel('Cumulative Capacity (Ah)'); title('Discharge Capacity', 'FontWeight', 'normal'); legend show;
subplot(1, 2, 2);
hold on;
for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).Charge_Capacity_Ah, 'LineWidth', plotLineWidth, 'Color', colors(mod(i-1, size(colors,1))+1,:), 'DisplayName', sprintf('Battery #%d', i));
end
hold off;
ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on';
xlabel('Time (s)'); ylabel('Cumulative Capacity (Ah)'); title('Charge Capacity', 'FontWeight', 'normal'); legend show;
sgtitle('Cumulative Capacity over Time', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', plotFontStyle);

fprintf('모든 플롯 생성을 완료했습니다.\n');