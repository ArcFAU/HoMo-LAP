function sig = setupSig(v)
%HOTLAP.SETUPSIG  Short hash of a setup's values (same as setupSig() in the web game), so a changed
%   setup starts a new best lap. FNV-1a over the values printed with 4 decimals, in base 36.
S = hotlap.setups(); keys = S.fields(:, 1);
str = strjoin(cellfun(@(k) sprintf('%.4f', v.(k)), keys, 'UniformOutput', false), ',');
h = uint64(2166136261);
for ch = double(str)
    h = bitxor(h, uint64(ch));
    h = mod(h * uint64(16777619), uint64(2)^32);
end
sig = lower(dec2base(double(h), 36));
end
