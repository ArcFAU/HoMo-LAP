function P = physicsData(T, C, mode)
%HOTLAP.PHYSICSDATA  Track data hotlap.physicsStep needs: curvature, brake-assist plan, world edge.
%   mode 'free' uses the larger free-roam world.
if nargin < 3, mode = 'sim'; end
[vPlan, vPlanA] = hotlap.planSpeeds(T, C);
if strcmp(mode, 'free'), w = T.WORLD_F; else, w = T.WORLD_T; end
P = struct('N', T.N, 'K', T.K, 'vPlan', vPlan, 'vPlanA', vPlanA, 'world', w);
end
