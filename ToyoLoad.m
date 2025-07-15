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

    % [추가됨] 파일 이름이 숫자로만 구성된 파일만 필터링합니다. (예: '000001', '000002')
    allFileNames = {theFiles.name}; % 모든 파일 이름을 cell 배열로 추출
    isNumericName = ~cellfun('isempty', regexp(allFileNames, '^\d+$')); % 이름이 숫자로만 구성되었는지 확인
    theFiles = theFiles(isNumericName); % 숫자 형식의 파일만 남김
    
    % 3. 필터링된 파일들을 이름 순으로 정렬합니다.
    if ~isempty(theFiles)
        % 이제 모든 파일 이름이 숫자이므로, 숫자로 변환하여 정확하게 정렬합니다.
        [~, sortOrder] = sort(str2double({theFiles.name}));
        theFiles = theFiles(sortOrder);
    else
        disp('폴더에 숫자 형식의 데이터 파일이 없습니다. (예: 000001)');
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
        opts.VariableNamingRule = 'preserve';
        
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
            allData{end+1} = dataTable;
            
        catch ME
            fprintf('경고: 파일 %s 처리 중 문제가 발생하여 건너뜁니다. (에러: %s)\n', baseFileName, ME.message);
        end
    end

    % 7. 모든 데이터 테이블을 수직으로 하나로 합칩니다.
    if ~isempty(allData)
        combinedData = vertcat(allData{:});
        
        disp('========================================');
        disp('데이터 통합 완료!');
        fprintf('통합된 데이터 테이블의 크기: %d x %d\n', size(combinedData, 1), size(combinedData, 2));
        disp('통합된 데이터 상위 5개 행:');
        disp(head(combinedData, 5));
        
    else
        disp('데이터를 성공적으로 읽어오지 못했습니다.');
        combinedData = [];
    end
end