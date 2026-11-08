function r = root()
%HOTLAP.ROOT  Folder of the MATLAB edition (the folder that holds +hotlap).
r = fileparts(fileparts(mfilename('fullpath')));
end
