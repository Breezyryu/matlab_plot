% MATLAB Script for Battery Data Visualization (Phase-Resetting Capacity Logic)

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
end

% --- 2.5. 구간별 용량 계산 (★사용자 정의 방식 적용) ---
fprintf('각 충/방전 구간마다 용량을 0부터 새로 계산합니다...\n');
for i = 1:numBatteries
    % 결과를 저장할 벡터 초기화
    phase_charge_Ah = zeros(size(batteryData(i).Time));
    phase_discharge_Ah = zeros(size(batteryData(i).Time));
    
    % 상태 정의: 1=충전, -1=방전, 0=휴지
    state = [0; sign(diff(batteryData(i).SOC))]; % 각 시점의 상태
    
    for k = 2:length(state)
        % 다음 스텝의 용량을 이전 스텝 값으로 우선 초기화
        phase_charge_Ah(k) = phase_charge_Ah(k-1);
        phase_discharge_Ah(k) = phase_discharge_Ah(k-1);
        
        % 상태가 변경되었는지 확인
        if state(k) ~= state(k-1)
            % 새로운 상태에 따라 해당 용량 누적치를 0으로 리셋
            if state(k) == 1 % 충전 시작
                phase_charge_Ah(k) = 0;
            elseif state(k) == -1 % 방전 시작
                phase_discharge_Ah(k) = 0;
            end
        end
        
        % 현재 스텝의 용량 계산
        dt_seconds = batteryData(i).Time(k) - batteryData(i).Time(k-1);
        avg_current = (abs(batteryData(i).Current(k)) + abs(batteryData(i).Current(k-1))) / 2;
        step_Ah = (avg_current * dt_seconds) / 3600;
        
        % 현재 상태에 따라 계산된 용량을 더함
        if state(k) == 1 % 충전 중
            phase_charge_Ah(k) = phase_charge_Ah(k) + step_Ah;
        elseif state(k) == -1 % 방전 중
            phase_discharge_Ah(k) = phase_discharge_Ah(k) + step_Ah;
        end
    end
    
    % 계산된 결과를 구조체에 저장
    batteryData(i).Phase_Charge_Ah = phase_charge_Ah;
    batteryData(i).Phase_Discharge_Ah = phase_discharge_Ah;
end
fprintf('구간별 용량 계산을 완료했습니다.\n');

% --- 2.6. 사이클별 분석을 위한 전체 누적 용량 계산 (백그라운드 계산) ---
% 이 부분은 플롯 5(사이클 성능 분석)를 위해 필요합니다.
for i = 1:numBatteries
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
    batteryData(i).Total_Charge_Ah = charge_capacity_Ah;
    batteryData(i).Total_Discharge_Ah = discharge_capacity_Ah;
    % 사이클 분석 로직
    state = [0; sign(diff(batteryData(i).SOC))];
    cycle_count = 0; charge_start_cap = 0; discharge_start_cap = 0; cycle_data = [];
    for k = 2:length(state)
        if state(k-1) == -1 && state(k) == 1
            discharge_end_cap = batteryData(i).Total_Discharge_Ah(k-1);
            temp_discharge_Ah = discharge_end_cap - discharge_start_cap;
            discharge_start_cap = discharge_end_cap;
        end
        if state(k-1) == 1 && state(k) == -1
            cycle_count = cycle_count + 1;
            charge_end_cap = batteryData(i).Total_Charge_Ah(k-1);
            cycle_charge_Ah = charge_end_cap - charge_start_cap;
            charge_start_cap = charge_end_cap;
            if cycle_charge_Ah > 0; CE = (temp_discharge_Ah / cycle_charge_Ah) * 100; else; CE = NaN; end
            cycle_data(cycle_count).Cycle_Number = cycle_count;
            cycle_data(cycle_count).Discharge_Ah = temp_discharge_Ah;
            cycle_data(cycle_count).Charge_Ah = cycle_charge_Ah;
            cycle_data(cycle_count).CE = CE;
        end
    end
    batteryData(i).Cycle_Data = cycle_data;
end


% --- 3. 데이터 시각화 ---
plotFontStyle = 'Arial'; plotFontSize = 12; plotLineWidth = 1.5; axisLineWidth = 1.2;
colors = [0, 114, 178; 213, 94, 0; 0, 158, 115] / 255; 

% 플롯 1, 2, 3 (생략) ...

%% 플롯 4: 구간별 누적 용량 (★요청사항 적용된 새 플롯)
figure('Color', 'white', 'Name', 'Phase-Specific Capacity');
for i = 1:numBatteries
    subplot(numBatteries, 1, i);
    hold on;
    % 충전 구간 용량 플롯
    plot(batteryData(i).Time, batteryData(i).Phase_Charge_Ah, 'LineWidth', plotLineWidth, 'Color', colors(2,:), 'DisplayName', 'Charge');
    % 방전 구간 용량 플롯
    plot(batteryData(i).Time, batteryData(i).Phase_Discharge_Ah, 'LineWidth', plotLineWidth, 'Color', colors(1,:), 'DisplayName', 'Discharge');
    hold off;
    
    title(sprintf('Battery #%d: Phase-Specific Accumulated Capacity', i));
    xlabel('Time (s)');
    ylabel('Capacity (Ah)');
    legend;
    grid on;
end
sgtitle('Capacity Accumulation per Charge/Discharge Phase', 'FontSize', 14, 'FontWeight', 'bold');

%% 플롯 5: 사이클별 용량 및 쿨롱 효율 (이전과 동일)
figure('Color', 'white', 'Name', 'Cycle Analysis');
for i = 1:numBatteries
    if isempty(batteryData(i).Cycle_Data); continue; end
    cycle_table = struct2table(batteryData(i).Cycle_Data);
    subplot(numBatteries, 2, (i-1)*2 + 1);
    plot(cycle_table.Cycle_Number, cycle_table.Discharge_Ah, '-o', 'LineWidth', plotLineWidth, 'Color', colors(1,:));
    hold on;
    plot(cycle_table.Cycle_Number, cycle_table.Charge_Ah, '-s', 'LineWidth', plotLineWidth, 'Color', colors(2,:));
    hold off;
    title(sprintf('Battery #%d: Capacity Fade', i));
    xlabel('Cycle Number'); ylabel('Capacity (Ah)');
    legend('Discharge', 'Charge', 'Location', 'northeast'); grid on;
    
    subplot(numBatteries, 2, i*2);
    bar(cycle_table.Cycle_Number, cycle_table.CE, 'FaceColor', colors(3,:));
    title(sprintf('Battery #%d: Coulombic Efficiency', i));
    xlabel('Cycle Number'); ylabel('Efficiency (%)');
    ylim([min(80, min(cycle_table.CE-5)), 105]); grid on;
end
sgtitle('Cycle Performance Analysis', 'FontSize', 14, 'FontWeight', 'bold');