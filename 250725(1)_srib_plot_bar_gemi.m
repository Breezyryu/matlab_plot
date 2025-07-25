#% 1. 폴더 경로 지정
folderPath = 'your_folder_path_here';  % 실제 CSV 파일이 있는 폴더 경로로 변경하세요.

% 2. CSV 파일 목록 가져오기
files = dir(fullfile(folderPath, '*.csv'));

% 3. 데이터 저장할 셀 배열 초기화
dataCell = cell(length(files), 1);

% 4. 각 파일을 읽어와 셀 배열에 저장
% 열 정보: Cycle_Number, Time_s, Voltage_V, Current_mA, Temperature_C, Capacity_mAh
for i = 1:length(files)
    filePath = fullfile(folderPath, files(i).name);
    try
        data = readtable(filePath);
        dataCell{i} = data;
    catch ME
        warning('파일을 읽는 중 오류가 발생했습니다: %s. 건너뜁니다.', files(i).name);
        disp(ME.message);
    end
end
dataCell = dataCell(~cellfun('isempty', dataCell)); % 오류가 발생한 셀은 제거

% 5. 각 파일(dataCell) 별로 독립적으로 처리 및 scatter plot
for i = 1:length(dataCell)
    % 새로운 figure 생성
    fig = figure('Name', sprintf('File: %s', files(i).name), 'Position', [100, 100, 850, 700]);
    
    % --- 수정: axes 위치 조정으로 UI 컨트롤과 라벨이 겹치지 않도록 함 ---
    % bottom을 0.15 -> 0.25로, height를 0.75 -> 0.65로 조정하여 하단에 여유 공간 확보
    ax = axes('Parent', fig, 'Position', [0.1, 0.25, 0.78, 0.65]); 
    hold(ax, 'on');
    
    % 현재 파일의 데이터
    data = dataCell{i};
    
    % 6. 사이클에 따른 데이터 분류
    uniqueCycles = sort(unique(data.Cycle_Number));
    if isempty(uniqueCycles)
        warning('파일 %s에 유효한 사이클 데이터가 없습니다. 건너뜁니다.', files(i).name);
        continue;
    end
    
    % Colormap 설정
    cmap = parula(length(uniqueCycles));
    
    % 모든 사이클에 대한 scatter 핸들 미리 생성 (초기에는 숨김)
    scatterHandles = gobjects(length(uniqueCycles), 1);
    for j = 1:length(uniqueCycles)
        cycle = uniqueCycles(j);
        cycleData = data(data.Cycle_Number == cycle, :);
        scatterHandles(j) = scatter(ax, cycleData.Capacity_mAh, cycleData.Voltage_V, 10, cmap(j, :), 'filled');
    end
    
    % 컬러바 추가
    colormap(ax, cmap);
    c = colorbar(ax);
    c.Label.String = 'Cycle Number';
    clim(ax, [uniqueCycles(1), uniqueCycles(end)]);

    % 논문용 figure 스타일 설정
    xlabel(ax, 'Capacity (mAh)', 'FontSize', 14, 'FontWeight', 'bold');
    ylabel(ax, 'Voltage (V)', 'FontSize', 14, 'FontWeight', 'bold');
    title(ax, sprintf('Voltage vs Capacity per Cycle (File %d)', i), 'FontSize', 16, 'FontWeight', 'bold');
    grid(ax, 'on');
    box(ax, 'on');
    set(ax, 'FontSize', 12, 'LineWidth', 1);

    % --- UI 컨트롤 (슬라이더, 입력 상자, 버튼) 생성 ---
    % --- 수정: 컨트롤 위치를 figure 하단으로 이동하여 그래프를 가리지 않도록 함 ---
    
    % 슬라이더 스텝 계산
    numCycles = length(uniqueCycles);
    sliderStep = [1/(numCycles-1), 10/(numCycles-1)]; % Minor step: 1, Major step: 10
    if numCycles <= 1
        sliderStep = [0, 0];
    end

    % Min/Max 사이클 슬라이더
    minSlider = uicontrol('Parent', fig, 'Style', 'slider', 'Position', [80, 70, 300, 20], ...
                          'Value', 1, 'Min', 1, 'Max', numCycles, 'SliderStep', sliderStep);
    maxSlider = uicontrol('Parent', fig, 'Style', 'slider', 'Position', [450, 70, 300, 20], ...
                          'Value', numCycles, 'Min', 1, 'Max', numCycles, 'SliderStep', sliderStep);

    % Min/Max 사이클 입력 상자
    minEdit = uicontrol('Parent', fig, 'Style', 'edit', 'Position', [80, 25, 100, 25], ...
                        'String', num2str(uniqueCycles(1)), 'FontSize', 10);
    maxEdit = uicontrol('Parent', fig, 'Style', 'edit', 'Position', [200, 25, 100, 25], ...
                        'String', num2str(uniqueCycles(end)), 'FontSize', 10);
                        
    % 업데이트 버튼
    updateButton = uicontrol('Parent', fig, 'Style', 'pushbutton', 'Position', [320, 25, 100, 25], ...
                             'String', 'Update', 'FontSize', 10, 'FontWeight', 'bold');

    % UI 컨트롤 라벨
    uicontrol('Parent', fig, 'Style', 'text', 'Position', [80, 90, 150, 20], 'String', 'Min Cycle Slider', 'HorizontalAlignment', 'left');
    uicontrol('Parent', fig, 'Style', 'text', 'Position', [450, 90, 150, 20], 'String', 'Max Cycle Slider', 'HorizontalAlignment', 'left');
    uicontrol('Parent', fig, 'Style', 'text', 'Position', [80, 50, 100, 20], 'String', 'Min Cycle', 'HorizontalAlignment', 'left');
    uicontrol('Parent', fig, 'Style', 'text', 'Position', [200, 50, 100, 20], 'String', 'Max Cycle', 'HorizontalAlignment', 'left');

    % --- 콜백(Callback) 함수 설정 ---
    % --- 수정: 슬라이더와 버튼의 콜백을 분리하여 로직을 명확화 ---
    addlistener(minSlider, 'ContinuousValueChange', @(s, e) updatePlotFromSliders(minSlider, maxSlider, minEdit, maxEdit, scatterHandles, uniqueCycles));
    addlistener(maxSlider, 'ContinuousValueChange', @(s, e) updatePlotFromSliders(minSlider, maxSlider, minEdit, maxEdit, scatterHandles, uniqueCycles));
    updateButton.Callback = @(s, e) updatePlotFromEdits(minSlider, maxSlider, minEdit, maxEdit, scatterHandles, uniqueCycles);

    % 초기 플롯 업데이트 호출
    updatePlotFromSliders(minSlider, maxSlider, minEdit, maxEdit, scatterHandles, uniqueCycles);
end

% --- 로컬 함수: 콜백 ---

% 슬라이더 값 변경 시 호출되는 함수
function updatePlotFromSliders(minSlider, maxSlider, minEdit, maxEdit, handles, uniqueCycles)
    minIdx = round(minSlider.Value);
    maxIdx = round(maxSlider.Value);
    
    % Min 슬라이더가 Max 슬라이더를 넘지 않도록 보정
    if minIdx > maxIdx
        minSlider.Value = maxIdx;
        minIdx = maxIdx;
    end
    
    % 플롯 업데이트
    set(handles, 'Visible', 'off');
    set(handles(minIdx:maxIdx), 'Visible', 'on');
    
    % 입력 상자(Edit) 텍스트 업데이트
    set(minEdit, 'String', num2str(uniqueCycles(minIdx)));
    set(maxEdit, 'String', num2str(uniqueCycles(maxIdx)));
end

% 'Update' 버튼 클릭 시 호출되는 함수
function updatePlotFromEdits(minSlider, maxSlider, minEdit, maxEdit, handles, uniqueCycles)
    % 입력 상자에서 값 읽기
    minCycle_str = get(minEdit, 'String');
    maxCycle_str = get(maxEdit, 'String');
    
    minCycle = str2double(minCycle_str);
    maxCycle = str2double(maxCycle_str);
    
    % --- 입력값 검증 ---
    if isnan(minCycle) || isnan(maxCycle)
        warndlg('유효한 숫자를 입력하세요.', '입력 오류');
        return;
    end
    
    if minCycle > maxCycle
        warndlg('최소 사이클 값은 최대 사이클 값보다 작거나 같아야 합니다.', '입력 오류');
        return;
    end
    
    if minCycle < uniqueCycles(1) || maxCycle > uniqueCycles(end)
        warndlg(sprintf('사이클은 %d와 %d 사이의 값이어야 합니다.', uniqueCycles(1), uniqueCycles(end)), '입력 오류');
        return;
    end
    
    % 입력된 사이클 값과 가장 가까운 인덱스 찾기
    [~, minIdx] = min(abs(uniqueCycles - minCycle));
    [~, maxIdx] = min(abs(uniqueCycles - maxCycle));
    
    % 플롯 업데이트
    set(handles, 'Visible', 'off');
    set(handles(minIdx:maxIdx), 'Visible', 'on');
    
    % 슬라이더 위치 업데이트
    set(minSlider, 'Value', minIdx);
    set(maxSlider, 'Value', maxIdx);
    
    % 입력 상자 텍스트를 실제 선택된 사이클 번호로 다시 설정 (근사값 처리)
    set(minEdit, 'String', num2str(uniqueCycles(minIdx)));
    set(maxEdit, 'String', num2str(uniqueCycles(maxIdx)));
end

