function combinedData = combineBatteryData()
    % 1. 사용자에게 데이터 파일이 있는 폴더를 선택하도록 요청합니다.
    folderPath = uigetdir('', '데이터 파일이 있는 폴더를 선택하세요');

    % 사용자가 폴더 선택을 취소한 경우, 스크립트를 종료합니다.
    if folderPath == 0
        disp('폴더 선택을 취소했습니다.');
        combinedData = [];
        return;
    end

    % 2. 폴더 내의 모든 파일 목록을 가져옵니다.
    filePattern = fullfile(folderPath, '*');
    theFiles = dir(filePattern);

    % 폴더(directory)는 제외합니다.
    theFiles = theFiles(~[theFiles.isdir]);

    % [수정됨] 파일 이름이 6자리 숫자로만 구성된 파일만 필터링합니다. (예: '000001', '000993')
    allFileNames = {theFiles.name}; % 모든 파일 이름을 cell 배열로 추출
    isNumericName = ~cellfun('isempty', regexp(allFileNames, '^\d{6}$')); % 이름이 정확히 6자리 숫자인지 확인
    theFiles = theFiles(isNumericName); % 6자리 숫자 형식의 파일만 남김
    
    % 3. 필터링된 파일들을 이름 순으로 정렬합니다.
    if ~isempty(theFiles)
        % 이제 모든 파일 이름이 6자리 숫자이므로, 숫자로 변환하여 정확하게 정렬합니다.
        [~, sortOrder] = sort(str2double({theFiles.name}));
        theFiles = theFiles(sortOrder);
    else
        disp('폴더에 6자리 숫자 형식의 데이터 파일이 없습니다. (예: 000001, 000993)');
        combinedData = [];
        return;
    end

    % 4. 첫 번째 파일을 기준으로 데이터 가져오기 '규칙(옵션)'을 설정합니다.
    try
        firstFile = fullfile(folderPath, theFiles(1).name);
        fprintf('가져오기 규칙 설정을 위해 첫 파일을 분석합니다: %s\n', theFiles(1).name);
        
        opts = detectImportOptions(firstFile, 'FileType', 'text', 'NumHeaderLines', 3);
        opts.Delimiter = ',';
        opts.ConsecutiveDelimitersRule = 'split';
        opts.EmptyLineRule = 'skip';
        opts.VariableNamingRule = 'preserve'; % 원래 열 제목 유지
        
        % 첫 번째 파일을 읽어서 기준 테이블 구조를 확인합니다.
        referenceTable = readtable(firstFile, opts);
        referenceVarNames = referenceTable.Properties.VariableNames;
        referenceNumVars = width(referenceTable);
        
        fprintf('기준 테이블 변수 개수: %d\n', referenceNumVars);
        fprintf('기준 테이블 변수 이름: %s\n', strjoin(referenceVarNames, ', '));
        
    catch ME
        fprintf('오류: 첫 파일로부터 데이터 형식을 분석할 수 없습니다. 에러: %s\n', ME.message);
        combinedData = [];
        return;
    end

    % 5. 모든 데이터를 저장할 빈 cell 배열을 초기화합니다.
    allData = {};

    % 6. 정렬된 파일 목록을 순회하며 각 파일을 읽습니다.
    for i = 1:length(theFiles)
        baseFileName = theFiles(i).name;
        fullFileName = fullfile(folderPath, baseFileName);
        
        fprintf('파일 읽는 중: %s\n', fullFileName);
        
        try
            dataTable = readtable(fullFileName, opts);
            
            % [추가됨] 변수 개수가 일치하는지 확인합니다.
            currentNumVars = width(dataTable);
            if currentNumVars ~= referenceNumVars
                fprintf('경고: 파일 %s의 변수 개수(%d)가 기준 파일의 변수 개수(%d)와 다릅니다. 건너뜁니다.\n', ...
                    baseFileName, currentNumVars, referenceNumVars);
                continue;
            end
            
            % [추가됨] 변수 이름이 일치하는지 확인합니다.
            currentVarNames = dataTable.Properties.VariableNames;
            if ~isequal(currentVarNames, referenceVarNames)
                fprintf('경고: 파일 %s의 변수 이름이 기준 파일과 다릅니다. 건너뜁니다.\n', baseFileName);
                fprintf('  기준: %s\n', strjoin(referenceVarNames, ', '));
                fprintf('  현재: %s\n', strjoin(currentVarNames, ', '));
                continue;
            end
            
            allData{end+1} = dataTable;
            
        catch ME
            fprintf('경고: 파일 %s 처리 중 문제가 발생하여 건너뜁니다. (에러: %s)\n', baseFileName, ME.message);
        end
    end

    % 7. 모든 데이터 테이블을 수직으로 하나로 합칩니다.
    if ~isempty(allData)
        try
            combinedData = vertcat(allData{:});
            
            % 8. 누적시간 열을 생성합니다.
            combinedData = addCumulativeTime(combinedData);
            
            disp('========================================');
            disp('데이터 통합 완료!');
            fprintf('처리된 파일 개수: %d / %d\n', length(allData), length(theFiles));
            fprintf('통합된 데이터 테이블의 크기: %d x %d\n', size(combinedData, 1), size(combinedData, 2));
            disp('통합된 데이터 상위 5개 행:');
            disp(head(combinedData, 5));
            disp('통합된 데이터 하위 5개 행:');
            disp(tail(combinedData, 5));
            
        catch ME
            fprintf('오류: 데이터 테이블 통합 중 문제가 발생했습니다. 에러: %s\n', ME.message);
            combinedData = [];
        end
        
    else
        disp('데이터를 성공적으로 읽어오지 못했습니다.');
        combinedData = [];
    end
end

function dataTable = addCumulativeTime(dataTable)
    % PassTime이 리셋되는 지점을 찾아서 누적시간을 계산합니다.
    
    % PassTime 열 찾기 (대소문자 구분 없이, 다양한 형태 지원)
    varNames = dataTable.Properties.VariableNames;
    passTimeIdx = [];
    
    % PassTime 관련 열 이름들을 찾습니다
    possibleNames = {'PassTime', 'PassTime[Sec]', 'PassTime_Sec', 'passtime', 'Pass_Time'};
    for i = 1:length(varNames)
        for j = 1:length(possibleNames)
            if contains(lower(varNames{i}), lower(possibleNames{j}))
                passTimeIdx = i;
                passTimeVarName = varNames{i};
                break;
            end
        end
        if ~isempty(passTimeIdx)
            break;
        end
    end
    
    if isempty(passTimeIdx)
        warning('PassTime 열을 찾을 수 없습니다. 다음 열들이 있습니다: %s', strjoin(varNames, ', '));
        return;
    end
    
    fprintf('PassTime 열 발견: %s\n', passTimeVarName);
    
    % PassTime 데이터 추출
    passTime = dataTable{:, passTimeIdx};
    numRows = length(passTime);
    
    % 누적시간 배열 초기화
    cumulativeTime = zeros(numRows, 1);
    
    if numRows == 0
        dataTable.CumulativeTime_Sec = cumulativeTime;
        return;
    end
    
    % 첫 번째 값 설정
    cumulativeTime(1) = passTime(1);
    timeOffset = 0; % 누적 오프셋
    
    % 리셋 지점을 찾아서 누적시간 계산
    resetCount = 0;
    for i = 2:numRows
        % PassTime이 이전 값보다 작으면 리셋된 것으로 판단
        if passTime(i) < passTime(i-1)
            % 리셋 지점 발견
            timeOffset = cumulativeTime(i-1); % 이전까지의 최대 누적시간을 오프셋으로 설정
            resetCount = resetCount + 1;
            fprintf('PassTime 리셋 지점 %d 발견: 행 %d (%.1f -> %.1f초)\n', ...
                resetCount, i, passTime(i-1), passTime(i));
        end
        
        cumulativeTime(i) = timeOffset + passTime(i);
    end
    
    % 새로운 열을 테이블에 추가
    dataTable.CumulativeTime_Sec = cumulativeTime;
    
    fprintf('누적시간 열 생성 완료!\n');
    fprintf('- 총 리셋 지점: %d개\n', resetCount);
    fprintf('- PassTime 범위: %.1f ~ %.1f초\n', min(passTime), max(passTime));
    fprintf('- 누적시간 범위: %.1f ~ %.1f초 (총 %.2f시간)\n', ...
        min(cumulativeTime), max(cumulativeTime), max(cumulativeTime)/3600);
end
end