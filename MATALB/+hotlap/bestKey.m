function k = bestKey(entry, mode, assist)
%HOTLAP.BESTKEY  Key of the best lap for a setup, mode and assist setting (same keys as the web game).
switch mode
    case 'arcade', k = 'arc|';
    case 'free',   k = 'free|';
    otherwise,     k = '';
end
k = [k entry.id];
if entry.custom, k = [k '#' hotlap.setupSig(entry.vals)]; end
if strcmp(mode, 'sim') && ~assist, k = [k '|raw']; end
end
