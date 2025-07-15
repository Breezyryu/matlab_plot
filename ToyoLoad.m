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
    % 파일명이 숫자로 되어 있으므로, 이름순으로 정렬하여 순서를 보장합니다.
    filePattern = fullfile(folderPath, '*');
    theFiles = dir(filePattern);

    % 폴더(directory)는 제외하고 파일만 필터링합니다.
    theFiles = theFiles(~[theFiles.isdir]);
    
    % 파일 이름을 기준으로 오름차순 정렬합니다.
    [~, sortOrder] = sort(str2double(regexp({theFiles.name}, '\d+', 'match', 'once')));
    theFiles = theFiles(sortOrder);


    % 3. 모든 파일의 데이터를 저장할 빈 cell 배열을 초기화합니다.
    allData = {};

    % 4. 정렬된 파일 목록을 순회하며 각 파일을 읽습니다.
    for i = 1:length(theFiles)
        baseFileName = theFiles(i).name;
        fullFileName = fullfile(folderPath, baseFileName);
        
        fprintf('파일 읽는 중: %s\n', fullFileName);
        
        try
            % 5. 각 파일에서 데이터를 읽습니다.
            % 파일 형식에 맞춰 앞 4줄(메타데이터)을 건너뛰고 데이터를 읽습니다.
            % readtable이 자동으로 4번째 줄을 헤더로 인식하게끔 'NumHeaderLines'를 3으로 설정합니다.
            opts = detectImportOptions(fullFileName, 'FileType', 'text', 'NumHeaderLines', 3);
            
            % 쉼표(,)를 구분자로 설정합니다.
            opts.Delimiter = ',';
            
            % 연속된 구분자를 단일 구분자로 처리하고, 빈 필드를 NaN으로 가져옵니다.
            opts.ConsecutiveDelimitersRule = 'split';
            opts.EmptyLineRule = 'skip';
            
            % 테이블 형식으로 데이터를 읽어옵니다.
            dataTable = readtable(fullFileName, opts);
            
            % 6. 읽어온 데이터를 cell 배열에 추가합니다.
            allData{end+1} = dataTable;
            
        catch ME
            % 파일 읽기 중 오류 발생 시 메시지를 출력합니다.
            fprintf('오류: 파일 %s를 읽을 수 없습니다. 에러 메시지: %s\n', baseFileName, ME.message);
        end
    end

    % 7. 모든 데이터 테이블을 수직으로 하나로 합칩니다.
    if ~isempty(allData)
        combinedData = vertcat(allData{:});
        
        % 합쳐진 데이터의 크기와 처음 5개 행을 출력하여 확인합니다.
        disp('========================================');
        disp('데이터 통합 완료!');
        fprintf('통합된 데이터 테이블의 크기: %d x %d\n', size(combinedData, 1), size(combinedData, 2));
        disp('통합된 데이터 상위 5개 행:');
        disp(head(combinedData, 5));
        
        % (선택 사항) 합쳐진 데이터를 새로운 CSV 파일로 저장
        % outputFileName = fullfile(folderPath, 'combined_battery_data.csv');
        % writetable(combinedData, outputFileName);
        % fprintf('통합된 데이터가 %s 파일로 저장되었습니다.\n', outputFileName);
        
    else
        disp('읽을 수 있는 데이터 파일이 없습니다.');
        combinedData = [];
    end
end