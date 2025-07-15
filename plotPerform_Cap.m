% MATLAB Script for Battery Data Visualization (with Cycle Analysis)

% --- 1. 파일 로드 및 2. 데이터 파싱 (이전과 동일) ---
files = dir('*.xlsx');
if isempty(files); error('현재 디렉토리에 XLSX 파일이 없습니다.'); end
filename = files(1).name;
fprintf('%s 파일을 불러옵니다.\n', filename);
T = readtable(filename, 'PreserveVariableNames', true);
[~, numCols] = size(T);
numVarsPerBattery = 8;
numBatteries = numCols / numVarsPerBattery;
fprintf('총 %d개의 배터리 데이터 세트를 발견했습니다.\n', numBatteries);
batteryData = struct();
for i = 1:numBatteries
    startCol = (i-1) * numVarsPerBattery + 1;
    tempTable = T(:, startCol:(startCol+7));
    batteryData(i).Time = tempTable{:, 1};
    batteryData(i).Voltage = tempTable{:, 2};
    batteryData(i).Current = tempTable{:, 3};
    batteryData(i).SOC = tempTable{:, 7};
    batteryData(i).Temp = tempTable{:, 8};
end

% --- 2.5. 전체 누적 용량 계산 (이전과 동일) ---
% 이 로직은 전체 시간에 대한 누적 그래프를 위해 유지됩니다.
fprintf('전체 시간에 대한 누적 용량을 계산합니다...\n');
for i = 1:numBatteries
    charge_cap = 0; discharge_cap = 0;
    charge_capacity_Ah = zeros(size(batteryData(i).Time));
    discharge_capacity_Ah = zeros(size(batteryData(i).Time));
    for k = 2:length(batteryData(i).Time)
        prev_charge_cap = charge_capacity_Ah(k-1);
        prev_discharge_cap = discharge_capacity_Ah(k-1);
        dt = batteryData(i).Time(k) - batteryData(i).Time(k-1);
        avg_I = (abs(batteryData(i).Current(k)) + abs(batteryData(i).Current(k-1))) / 2;
        step_Ah = (avg_I * dt) / 3600;
        if batteryData(i).SOC(k) > batteryData(i).SOC(k-1)
            charge_capacity_Ah(k) = prev_charge_cap + step_Ah;
            discharge_capacity_Ah(k) = prev_discharge_cap;
        elseif batteryData(i).SOC(k) < batteryData(i).SOC(k-1)
            discharge_capacity_Ah(k) = prev_discharge_cap + step_Ah;
            charge_capacity_Ah(k) = prev_charge_cap;
        else
            charge_capacity_Ah(k) = prev_charge_cap;
            discharge_capacity_Ah(k) = prev_discharge_cap;
        end
    end
    batteryData(i).Charge_Capacity_Ah = charge_capacity_Ah;
    batteryData(i).Discharge_Capacity_Ah = discharge_capacity_Ah;
end

% --- 2.6. 사이클별 용량 및 효율 분석 (★핵심 추가 기능) ---
fprintf('사이클별 용량 및 쿨롱 효율을 분석합니다...\n');
for i = 1:numBatteries
    % 상태 정의: 1=충전, -1=방전, 0=휴지
    soc_diff = diff(batteryData(i).SOC);
    state = sign(soc_diff);
    state = [0; state]; % 길이를 맞추기 위해 첫 상태는 휴지로 가정

    cycle_count = 0;
    charge_start_cap = 0;
    discharge_start_cap = 0;
    
    cycle_data = [];

    for k = 2:length(state)
        % 상태가 '방전'에서 '충전'으로 바뀔 때 -> 방전 half-cycle 종료
        if state(k-1) == -1 && state(k) == 1
            % 해당 방전 구간의 용량 계산
            discharge_end_cap = batteryData(i).Discharge_Capacity_Ah(k-1);
            cycle_discharge_Ah = discharge_end_cap - discharge_start_cap;
            
            % 다음 방전 사이클의 시작 용량 업데이트
            discharge_start_cap = discharge_end_cap;
            
            % 임시 저장
            temp_discharge_Ah = cycle_discharge_Ah;
        end
        
        % 상태가 '충전'에서 '방전'으로 바뀔 때 -> 충전 half-cycle 종료 (1 사이클 완성)
        if state(k-1) == 1 && state(k) == -1
            cycle_count = cycle_count + 1;
            
            % 해당 충전 구간의 용량 계산
            charge_end_cap = batteryData(i).Charge_Capacity_Ah(k-1);
            cycle_charge_Ah = charge_end_cap - charge_start_cap;
            
            % 다음 충전 사이클의 시작 용량 업데이트
            charge_start_cap = charge_end_cap;
            
            % 쿨롱 효율 계산
            if cycle_charge_Ah > 0
                coulombic_efficiency = (temp_discharge_Ah / cycle_charge_Ah) * 100;
            else
                coulombic_efficiency = NaN;
            end
            
            % 현재 사이클의 데이터 저장
            cycle_data(cycle_count).Cycle_Number = cycle_count;
            cycle_data(cycle_count).Discharge_Ah = temp_discharge_Ah;
            cycle_data(cycle_count).Charge_Ah = cycle_charge_Ah;
            cycle_data(cycle_count).CE = coulombic_efficiency;
        end
    end
    batteryData(i).Cycle_Data = cycle_data;
end
fprintf('사이클 분석을 완료했습니다.\n');

% --- 3. 데이터 시각화 ---
% 스타일 정의
plotFontStyle = 'Arial'; plotFontSize = 12; plotLineWidth = 1.5; axisLineWidth = 1.2;
colors = [0, 114, 178; 213, 94, 0; 0, 158, 115] / 255; 

% 플롯 1~4 (이전과 동일, 코드는 생략하지 않고 포함)
% ... (이전 코드와 동일하므로 여기에 전체 코드가 들어감) ...
% 플롯 1: 전압 및 전류
figure('Color', 'white', 'Name', 'Voltage and Current Analysis'); 
numRows = ceil(numBatteries / 2); numCols = 2;
for i = 1:numBatteries
    subplot(numRows, numCols, i); 
    yyaxis left; p1 = plot(batteryData(i).Time, batteryData(i).Voltage, 'LineWidth', plotLineWidth, 'Color', colors(1,:)); ylabel('Voltage (V)');
    yyaxis right; p2 = plot(batteryData(i).Time, batteryData(i).Current, '--', 'LineWidth', plotLineWidth, 'Color', colors(2,:)); ylabel('Current (A)');
    ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 10; ax.LineWidth = axisLineWidth; ax.Box = 'on'; ax.YAxis(1).Color = 'k'; ax.YAxis(2).Color = 'k'; 
    xlabel('Time (s)'); title(sprintf('Battery #%d', i), 'FontWeight', 'normal'); 
    if i == numBatteries; legend([p1, p2], {'Voltage', 'Current'}, 'Location', 'best'); end
end
sgtitle('Voltage and Current Profiles', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', plotFontStyle);
% 플롯 2: SOC
figure('Color', 'white', 'Name', 'SOC Comparison'); hold on;
for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).SOC, 'LineWidth', plotLineWidth, 'Color', colors(mod(i-1, size(colors,1))+1,:), 'DisplayName', sprintf('Battery #%d', i));
end
hold off; ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on'; xlabel('Time (s)'); ylabel('State of Charge, SOC (%)'); title('Comparison of SOC over Time', 'FontWeight', 'normal'); legend show;
% 플롯 3: V-SOC
figure('Color', 'white', 'Name', 'V-SOC Curve'); hold on;
for i = 1:numBatteries
    plot(batteryData(i).SOC, batteryData(i).Voltage, 'o', 'MarkerSize', 7, 'MarkerEdgeColor', colors(mod(i-1, size(colors,1))+1,:), 'DisplayName', sprintf('Battery #%d', i));
end
hold off; ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on'; xlabel('State of Charge, SOC (%)'); ylabel('Voltage (V)'); title('Voltage vs. SOC Profile', 'FontWeight', 'normal'); legend show; axis tight;
% 플롯 4: 충/방전 용량
figure('Color', 'white', 'Name', 'Charge-Discharge Capacity');
subplot(1, 2, 1); hold on;
for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).Discharge_Capacity_Ah, 'LineWidth', plotLineWidth, 'Color', colors(mod(i-1, size(colors,1))+1,:), 'DisplayName', sprintf('Battery #%d', i));
end
hold off; ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on'; xlabel('Time (s)'); ylabel('Cumulative Capacity (Ah)'); title('Discharge Capacity', 'FontWeight', 'normal'); legend show;
subplot(1, 2, 2); hold on;
for i = 1:numBatteries
    plot(batteryData(i).Time, batteryData(i).Charge_Capacity_Ah, 'LineWidth', plotLineWidth, 'Color', colors(mod(i-1, size(colors,1))+1,:), 'DisplayName', sprintf('Battery #%d', i));
end
hold off; ax = gca; ax.FontName = plotFontStyle; ax.FontSize = 12; ax.LineWidth = axisLineWidth; ax.Box = 'on'; xlabel('Time (s)'); ylabel('Cumulative Capacity (Ah)'); title('Charge Capacity', 'FontWeight', 'normal'); legend show;
sgtitle('Cumulative Capacity over Time', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', plotFontStyle);

%% 플롯 5: 사이클별 용량 및 쿨롱 효율 (★새로운 플롯)
figure('Color', 'white', 'Name', 'Cycle Analysis');
% 각 배터리별로 사이클 그래프 생성
for i = 1:numBatteries
    if isempty(batteryData(i).Cycle_Data)
        fprintf('배터리 #%d: 분석할 사이클 데이터가 없습니다.\n', i);
        continue;
    end
    
    % 구조체 배열에서 테이블로 변환하여 데이터 추출 용이
    cycle_table = struct2table(batteryData(i).Cycle_Data);
    
    % 1. 사이클별 용량 그래프
    subplot(numBatteries, 2, (i-1)*2 + 1);
    plot(cycle_table.Cycle_Number, cycle_table.Discharge_Ah, '-o', 'LineWidth', plotLineWidth, 'Color', colors(1,:));
    hold on;
    plot(cycle_table.Cycle_Number, cycle_table.Charge_Ah, '-s', 'LineWidth', plotLineWidth, 'Color', colors(2,:));
    hold off;
    title(sprintf('Battery #%d: Capacity Fade', i));
    xlabel('Cycle Number');
    ylabel('Capacity (Ah)');
    legend('Discharge', 'Charge', 'Location', 'northeast');
    grid on;
    
    % 2. 쿨롱 효율 그래프
    subplot(numBatteries, 2, i*2);
    bar(cycle_table.Cycle_Number, cycle_table.CE, 'FaceColor', colors(3,:));
    title(sprintf('Battery #%d: Coulombic Efficiency', i));
    xlabel('Cycle Number');
    ylabel('Efficiency (%)');
    ylim([min(80, min(cycle_table.CE-5)), 105]); % Y축 범위 조절
    grid on;
end
sgtitle('Cycle Performance Analysis', 'FontSize', 14, 'FontWeight', 'bold', 'FontName', plotFontStyle);

fprintf('모든 플롯 생성을 완료했습니다.\n');