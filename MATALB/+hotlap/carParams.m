function C = carParams(v)
%HOTLAP.CARPARAMS  Physics parameters from a setup (the vals struct of hotlap.setups).
%   C = hotlap.carParams(vals). Same as applySetup() in the web game.
%   Wheelbase, track width and the car model stay as built.
C.L = 1.53; C.tf = 1.24; C.tr = 1.20; C.Fz0 = 600; C.rr = 0.015; C.rho = 1.225; C.eta = 0.97; C.R = 0.202; C.C = 1.4;
C.m = v.mCar + v.mDrv;
C.b = v.wf * C.L; C.a = C.L - C.b;          % CoG to front axle a, to rear axle b
C.h = v.h; C.Iz = 135 * C.m / 252;
C.mu0 = v.mu0; C.muExp = v.muExp; C.ap = v.ap * pi / 180; C.B = tan(pi / (2 * C.C)) / C.ap;
C.Pmax = v.Pmax * 1000; C.Tm = v.Tm; C.G = v.G; C.nmax = v.nmax;
C.brakeFront = v.brakeFront; C.Fb = v.Fb; C.rollFront = v.rollFront; C.tv = v.tv; C.delMax = v.delMax * pi / 180;
C.ClA = v.ClA; C.CdA = v.CdA; C.bal = v.bal;
C.vMotor = C.nmax * 2 * pi / 60 / C.G * C.R;    % stock: 34.06 m/s, 122.6 km/h
C.FdMax = 4 * C.Tm * C.G * C.eta / C.R;          % stock: 5010 N at the contact patches
C.yawLoss = 0.0115;   % per degree of body slip: V4_K fine mesh, yaw 3 deg: CzA -6.706 -> -6.475
A = hotlap.setups(); C.arc = A.arc;
end
