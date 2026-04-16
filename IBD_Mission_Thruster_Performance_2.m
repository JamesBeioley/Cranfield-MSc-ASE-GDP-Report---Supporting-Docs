%% =========================================================================
%% IBD_Thruster_Performance_2_Final.m
%% =========================================================================
% Thruster Performance Database
%
% Purpose
%   Compile published throttle-curve data for the five shortlisted EP
%   thrusters, compute linear thrust-power slopes for first-order scaling,
%   and provide nominal specific impulse and lifetime values for use in
%   propellant and lifetime calculations throughout the IBD analysis.
%
% Assumptions
%   - Thrust-power relationship is approximated by a first-order linear
%     fit (polyfit, degree 1).  The slope [mN/W] is retained for scaling;
%     the intercept is not used.  This is a simplification: the fit is not
%     forced through the origin, so the slope alone may over- or under-
%     estimate thrust at the extremes of the throttle envelope.
%   - Specific impulse is taken as the arithmetic mean across all
%     published operating points.  A thrust-weighted mean would be more
%     rigorous for propellant budgets at a single operating point, but the
%     difference is small for these thrusters.
%
% Outputs
%   Structured:
%     IBD.thruster  — contains all data in a single struct
%   Legacy flat variables (for backward compatibility):
%     names, P_env
%     isp_next, isp_t6, isp_spt, isp_bht, isp_saf
%     life_next, life_t6, life_spt, life_bht, life_saf
%     TP_next, TP_t6, TP_spt, TP_bht, TP_saf  [mN/W]
%
% Recommended run order
%   1) IBD_Mission_Master_1.m
%   2) IBD_Thruster_Performance_2.m   <-- this script
%   3) IBD_Plots_3.m / IBD_Summary_Report_4.m / etc.
%
% Sources
%   NEXT-C  : Herman et al., "NEXT Long-Duration Test", AIAA 2012-3847
%   T6      : Wallace et al., QinetiQ T6 data, IEPC-2011-144
%   SPT-140 : Manzella et al., "SPT-140 Performance", IEPC-2001-065
%   BHT-6000: Busek published data sheets
%   PPS5000 : Dudeck et al., "PPS5000 Development Status", IEPC-2011
% =========================================================================

clc;

%% -------------------- A) Thruster set --------------------
names = {'NEXT-C', 'T6', 'SPT-140', 'BHT-6000', 'PPS5000'};
Nthr  = numel(names);

%% -------------------- B) Published throttle envelopes [W] --------------------
% Manufacturer-stated power range for each thruster.
P_env = [
    500   7500;   % NEXT-C
    2430  4500;   % T6
    900   4600;   % SPT-140
    3000  5000;   % BHT-6000
    2500  5500;   % PPS5000
];

%% -------------------- C) Operating-point data --------------------
% Power [W], Thrust [mN], Specific impulse [s]
% Values digitised or tabulated from the source references listed above.

% NEXT-C (gridded ion engine, xenon)
P_next = [640  1700 2150 2610 3480 4510 5650 5840 7330];
T_next = [25   59   69   78   137  159  178  208  235 ];
I_next = [1395 2953 3432 3882 3137 3626 4082 3683 4155];

% QinetiQ T6 (gridded ion engine, xenon)
P_t6 = [2430 3160 3920 4510];
T_t6 = [75   100  125  145 ];
I_t6 = [3710 3940 4080 4120];

% SPT-140 (Hall-effect thruster, xenon)
P_spt = [930  1520 2020 2530 3000 3580 4570];
T_spt = [57   100  132  158  189  222  279 ];
I_spt = [1400 1545 1627 1662 1710 1739 1794];

% BHT-6000 (Hall-effect thruster, xenon)
P_bht = [3000  4000  4500  5000 ];
T_bht = [191.4 249.5 276.6 302.4];
I_bht = [1794  1855  1878  1898 ];

% Safran PPS5000 (Hall-effect thruster, xenon)
P_saf = [2510 2570 2970 3160 3990 4410 4910 5480];
T_saf = [143  150  167  193  238  242  286  315 ];
I_saf = [1785 1853 1859 1805 1678 1694 1862 1753];

%% -------------------- D) Nominal Isp and lifetime --------------------
% Isp: arithmetic mean across published operating points [s]
% Lifetime: published or estimated qualification life [hr]

isp_next  = mean(I_next);    life_next = 50000;   % NEXT LDT
isp_t6    = mean(I_t6);      life_t6   = 20000;
isp_spt   = mean(I_spt);     life_spt  = 15000;
isp_bht   = mean(I_bht);     life_bht  = 15000;
isp_saf   = mean(I_saf);     life_saf  = 20000;

%% -------------------- E) Linear thrust-power slopes --------------------
% First-order fit: T [mN] = slope * P [W] + intercept
% Only the slope [mN/W] is retained for downstream scaling.

p_next = polyfit(P_next, T_next, 1);   TP_next = p_next(1);
p_t6   = polyfit(P_t6,   T_t6,   1);   TP_t6   = p_t6(1);
p_spt  = polyfit(P_spt,  T_spt,  1);   TP_spt  = p_spt(1);
p_bht  = polyfit(P_bht,  T_bht,  1);   TP_bht  = p_bht(1);
p_saf  = polyfit(P_saf,  T_saf,  1);   TP_saf  = p_saf(1);

%% -------------------- F) Structured output --------------------
% Package into IBD.thruster for use by downstream scripts.  Appends to the
% existing IBD struct if IBD_Mission_Master_1.m has already run.

if ~exist('IBD','var')
    IBD = struct();
end

% Cell arrays indexed by thruster number (same order as 'names')
IBD.thruster.names  = names;
IBD.thruster.P_env  = P_env;

IBD.thruster.P_data = {P_next, P_t6, P_spt, P_bht, P_saf};
IBD.thruster.T_data = {T_next, T_t6, T_spt, T_bht, T_saf};
IBD.thruster.I_data = {I_next, I_t6, I_spt, I_bht, I_saf};

IBD.thruster.isp     = [isp_next,  isp_t6,  isp_spt,  isp_bht,  isp_saf];
IBD.thruster.life_hr = [life_next, life_t6, life_spt, life_bht, life_saf];
IBD.thruster.TP_mN_per_W = [TP_next, TP_t6, TP_spt, TP_bht, TP_saf];

%% -------------------- G) Console summary --------------------
fprintf('\n');
fprintf('=====================================================================\n');
fprintf('THRUSTER DATABASE SUMMARY\n');
fprintf('=====================================================================\n');
fprintf('%12s | %8s | %8s | %10s | %6s\n', ...
    'Thruster', 'Isp [s]', 'Life [hr]', 'TP [mN/kW]', 'P range [W]');
fprintf('%s\n', repmat('-', 1, 60));

for k = 1:Nthr
    fprintf('%12s | %8.0f | %8.0f | %10.1f | %5.0f–%.0f\n', ...
        names{k}, ...
        IBD.thruster.isp(k), ...
        IBD.thruster.life_hr(k), ...
        1000 * IBD.thruster.TP_mN_per_W(k), ...
        P_env(k,1), P_env(k,2));
end

fprintf('=====================================================================\n\n');