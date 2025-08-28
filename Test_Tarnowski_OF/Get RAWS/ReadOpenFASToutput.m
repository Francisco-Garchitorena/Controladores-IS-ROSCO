function [tSeries] = ReadOpenFASToutput(FileName,vars)

indx = zeros(length(vars),1);


fid = fopen(FileName);
tline = fgetl(fid);

readHeader = false;

while ~readHeader
    
    if ~isempty(tline) 
        
        newStr = split(tline);
        
        if strcmp(newStr{1},'Time')
            readHeader = true;
            
            for i = 1:length(vars)
    
                Lvec = cellfun(@(x) ~isempty(strfind(vars{i}, x)), newStr); % Find the indexes of the variables that I want
                
                if isempty(find(Lvec==1))
                    disp(['Warning: variable ' vars{i} ' not found in output file'])
                    indx(i) = 0;
                else
                    indx(i) = find(Lvec==1);
                end
                    
    
            end

        
        end
        
    end
    
    tline = fgetl(fid); % La última vez que recorro el loop, aquí leo las unidades
end

cont = 1;
tline = fgetl(fid);

while ischar(tline)
    
    newStr = split(tline);
    
    for i = 1:length(vars)
        
        if indx(i) == 0
            tSeries(cont,i) = NaN;
        else
            tSeries(cont,i) = str2num(newStr{indx(i)+1}); % Le sumo 1 porque el primero siempre está vacío
        end
    end 
        
    cont = cont + 1;
    tline = fgetl(fid);
    
end
    


fclose(fid);