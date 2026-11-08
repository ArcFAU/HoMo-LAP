function inp = driverInput(steer, thr, brk, hb, assist, human, arcade)
%HOTLAP.DRIVERINPUT  Driver input struct for hotlap.physicsStep (unset flags are false).
if nargin < 4, hb = false; end
if nargin < 5, assist = false; end
if nargin < 6, human = false; end
if nargin < 7, arcade = false; end
inp = struct('steer', steer, 'thr', thr, 'brk', brk, 'hb', logical(hb), 'assist', logical(assist), 'human', logical(human), 'arcade', logical(arcade));
end
