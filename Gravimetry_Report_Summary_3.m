%% =========================================================================
%% Gradiometry_Report_Summary_3.m
%% =========================================================================
% NEO Gravity Gradiometry — Console Summary Report
%
% Purpose
%   Print a comprehensive console report for the gravity gradiometry
%   payload analysis, including:
%     - Single-point design summary
%     - Diameter sweep table
%     - Cross-instrument comparison at the reference point
%     - Two-asteroid comparison (2006 SU49 and 2017 SV19)
%     - Mission-facing detectability table (maximum stand-off)
%     - Mission-facing operations table (required time at fixed stand-off)
%     - Minimum detectable diameter at fixed stand-off
%     - Interpretive commentary for each section
%
% Recommended run order
%   1) Gradiometry_Core_1.m
%   2) Gradiometry_Report_Summary_3.m  <-- this script
% =========================================================================

clc;

if ~exist('NEO','var')
    error('Run Gradiometry_Core_1.m first.');
end

%% =========================================================================
%% A) REPORTING CONFIGURATION
%% =========================================================================
cfg = struct();

cfg.G          = NEO.const.G;
cfg.EOTVOS     = NEO.const.EOTVOS;
cfg.rho_kgm3   = NEO.cfg.rho_kgm3;

% Single-point design case
cfg.D_m        = 60;                 % asteroid diameter [m]
cfg.h_km       = 5.0;               % surface offset [km]
cfg.instrument = "GOCE (in-orbit)";
cfg.T_int_s    = 3600;              % integration time [s]
cfg.SNR_target = NEO.cfg.SNR_target;

% Diameter sweep (set [] to disable)
cfg.D_sweep_m = [20 30 40 60 100 200 377];

% Chosen asteroid summary
cfg.h_ast_km       = 5.0;
cfg.T_ast_s        = 3600;
cfg.instrument_ast = "GOCE (in-orbit)";
cfg.SNR_target_ast = cfg.SNR_target;

% Detectability table: integration times
cfg.T_detect_list_s = [1, 60, 3600, 86400, 604800, 2629800];
cfg.T_detect_labels = ["1 sec", "1 min", "1 hour", "1 day", "1 week", "1 month"];

% Fixed stand-off table
cfg.h_fixed_list_km = [0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0];
cfg.h_fixed_labels  = ["100 m", "250 m", "500 m", "1 km", "2.5 km", "5 km", "10 km"];
cfg.T_cap_s         = 1e12;

% Operational feasibility thresholds
cfg.arc_single_hr   = 6;        % single sustained science arc
cfg.arc_campaign_hr = 168;      % week-long observation campaign

%% =========================================================================
%% B) INSTRUMENT DATABASE
%% =========================================================================
instr = NEO.instr;

%% =========================================================================
%% C) SINGLE-POINT SUMMARY
%% =========================================================================
pt = compute_point(cfg, instr, cfg.D_m, cfg.h_km, cfg.T_int_s, cfg.instrument);
print_summary(cfg, pt);

%% =========================================================================
%% D) DIAMETER SWEEP
%% =========================================================================
if ~isempty(cfg.D_sweep_m)
    fprintf('\n');
    fprintf('=====================================================================\n');
    fprintf('DIAMETER SWEEP (fixed h = %.2f km, T = %.0f s, %s)\n', ...
        cfg.h_km, cfg.T_int_s, cfg.instrument);
    fprintf('=====================================================================\n');
    fprintf('%10s | %12s | %12s | %10s | %12s | %10s\n', ...
        'D [m]', 'Gamma [E]', 'g [uGal]', 'SNR', 'Treq [hr]', 'Detect?');
    fprintf('%s\n', repmat('-', 1, 78));

    for D_i = cfg.D_sweep_m
        pti = compute_point(cfg, instr, D_i, cfg.h_km, cfg.T_int_s, cfg.instrument);
        fprintf('%10.1f | %12.3e | %12.3e | %10.3f | %12.3f | %10s\n', ...
            pti.D_m, pti.gradE, pti.g_uGal, pti.SNR, pti.T_req_hr, passfail(pti.detectable));
    end
    fprintf('=====================================================================\n');
end

%% =========================================================================
%% E) CROSS-INSTRUMENT COMPARISON AT REFERENCE POINT
%% =========================================================================
fprintf('\n');
fprintf('=====================================================================\n');
fprintf('CROSS-INSTRUMENT COMPARISON\n');
fprintf('=====================================================================\n');
fprintf('Reference: D = %.0f m, h = %.2f km, T = %.0f s, rho = %.0f kg/m^3\n', ...
    cfg.D_m, cfg.h_km, cfg.T_int_s, cfg.rho_kgm3);
fprintf('=====================================================================\n');
fprintf('%32s | %12s | %10s | %12s | %10s\n', ...
    'Instrument', 'nE [E/rtHz]', 'SNR', 'Treq [hr]', 'Detect?');
fprintf('%s\n', repmat('-', 1, 88));

for k = 1:numel(instr)
    pti = compute_point(cfg, instr, cfg.D_m, cfg.h_km, cfg.T_int_s, string(instr(k).name));
    fprintf('%32s | %12.3e | %10.3f | %12.3f | %10s\n', ...
        instr(k).name, instr(k).nE, pti.SNR, pti.T_req_hr, passfail(pti.detectable));
end

fprintf('\nContext: GOCE measured Earth geoid features of ~1–3 E from a 260 km orbit.\n');
fprintf('A %.0f m asteroid at %.1f km offset produces %.3e E — orders of magnitude\n', ...
    cfg.D_m, cfg.h_km, pt.gradE);
fprintf('weaker, requiring extended integration or closer proximity.\n');
fprintf('=====================================================================\n');

%% =========================================================================
%% F) CHOSEN ASTEROID SUMMARY
%% =========================================================================
fprintf('\n');
fprintf('=====================================================================\n');
fprintf('TARGET ASTEROID SUMMARY\n');
fprintf('=====================================================================\n');
fprintf('Instrument: %s | h = %.2f km | T = %.0f s | rho = %.0f kg/m^3 | SNR = %.1f\n', ...
    cfg.instrument_ast, cfg.h_ast_km, cfg.T_ast_s, cfg.rho_kgm3, cfg.SNR_target);
fprintf('=====================================================================\n');

% 2006 SU49
pt_SU49 = compute_point(cfg, instr, 377, cfg.h_ast_km, cfg.T_ast_s, cfg.instrument_ast);

fprintf('\n-- 2006 SU49 (D = 377 m) --\n');
fprintf('Mass:          %.3e kg\n', pt_SU49.M_kg);
fprintf('g at S/C:      %.3e m/s^2  (%.3e uGal)\n', pt_SU49.g_ms2, pt_SU49.g_uGal);
fprintf('Gradient:      %.3e s^-2  (%.3e E)\n', pt_SU49.grad_s2, pt_SU49.gradE);
fprintf('SNR:           %.3f\n', pt_SU49.SNR);
fprintf('Treq:          %.3f hr  (%.3f days)\n', pt_SU49.T_req_hr, pt_SU49.T_req_days);
fprintf('Detectable:    %s\n', passfail(pt_SU49.detectable));

% Orbital context for SU49
print_orbital_context(cfg, 377, cfg.h_ast_km);

% 2017 SV19 range
D_SV19 = [20 40 60];

fprintf('\n-- 2017 SV19 (D = 20–60 m range) --\n');
fprintf('%8s | %12s | %12s | %10s | %12s | %10s\n', ...
    'D [m]', 'g [uGal]', 'Gamma [E]', 'SNR', 'Treq [hr]', 'Detect?');
fprintf('%s\n', repmat('-', 1, 74));

for D_i = D_SV19
    pti = compute_point(cfg, instr, D_i, cfg.h_ast_km, cfg.T_ast_s, cfg.instrument_ast);
    fprintf('%8.1f | %12.3e | %12.3e | %10.3f | %12.3f | %10s\n', ...
        pti.D_m, pti.g_uGal, pti.gradE, pti.SNR, pti.T_req_hr, passfail(pti.detectable));
end

% Orbital context for SV19 nominal
print_orbital_context(cfg, 40, cfg.h_ast_km);

%% =========================================================================
%% G) MAXIMUM DETECTABLE SURFACE OFFSET
%% =========================================================================
fprintf('\n');
fprintf('=====================================================================\n');
fprintf('MAXIMUM DETECTABLE SURFACE OFFSET\n');
fprintf('=====================================================================\n');
fprintf('Instrument: %s | SNR = %.1f | rho = %.0f kg/m^3\n', ...
    cfg.instrument_ast, cfg.SNR_target_ast, cfg.rho_kgm3);
fprintf('=====================================================================\n');

% SU49
fprintf('\n-- 2006 SU49 (D = 377 m) --\n');
fprintf('%10s | %14s | %14s | %12s\n', ...
    'T_int', 'h_max [km]', 'r_max [km]', 'Detectable?');
fprintf('%s\n', repmat('-', 1, 58));

for i = 1:numel(cfg.T_detect_list_s)
    T_i = cfg.T_detect_list_s(i);
    pt_det = compute_max_offset(cfg, instr, 377, T_i, cfg.instrument_ast);
    fprintf('%10s | %14.3f | %14.3f | %12s\n', ...
        cfg.T_detect_labels(i), pt_det.h_max_km, pt_det.r_max_km, passfail(pt_det.detectable_any));
end

% SV19 range
fprintf('\n-- 2017 SV19 (D = 20–60 m range) --\n');
fprintf('%8s | %10s | %14s | %14s | %12s\n', ...
    'D [m]', 'T_int', 'h_max [km]', 'r_max [km]', 'Detectable?');
fprintf('%s\n', repmat('-', 1, 66));

for D_i = D_SV19
    for i = 1:numel(cfg.T_detect_list_s)
        T_i = cfg.T_detect_list_s(i);
        pt_det = compute_max_offset(cfg, instr, D_i, T_i, cfg.instrument_ast);
        fprintf('%8.1f | %10s | %14.3f | %14.3f | %12s\n', ...
            D_i, cfg.T_detect_labels(i), pt_det.h_max_km, pt_det.r_max_km, ...
            passfail(pt_det.detectable_any));
    end
end

% Interpretation
fprintf('\n-- Interpretation --\n');

su49_h_1hr = compute_max_offset(cfg, instr, 377, 3600,   cfg.instrument_ast).h_max_km;
su49_h_1d  = compute_max_offset(cfg, instr, 377, 86400,  cfg.instrument_ast).h_max_km;
su49_h_1wk = compute_max_offset(cfg, instr, 377, 604800, cfg.instrument_ast).h_max_km;

fprintf('SU49: detection viable from significant stand-off.\n');
fprintf('  h_max = %.2f km (1 hr), %.2f km (1 day), %.2f km (1 week)\n', ...
    su49_h_1hr, su49_h_1d, su49_h_1wk);

sv19_h_1hr = zeros(size(D_SV19));
sv19_h_1d  = zeros(size(D_SV19));
for ii = 1:numel(D_SV19)
    sv19_h_1hr(ii) = compute_max_offset(cfg, instr, D_SV19(ii), 3600,  cfg.instrument_ast).h_max_km;
    sv19_h_1d(ii)  = compute_max_offset(cfg, instr, D_SV19(ii), 86400, cfg.instrument_ast).h_max_km;
end

fprintf('SV19: strongly size-dependent; requires close proximity.\n');
fprintf('  h_max at 1 hr: %.3f–%.3f km;  at 1 day: %.3f–%.3f km  (across D = 20–60 m)\n', ...
    min(sv19_h_1hr), max(sv19_h_1hr), min(sv19_h_1d), max(sv19_h_1d));

%% =========================================================================
%% H) REQUIRED INTEGRATION TIME AT FIXED STAND-OFF
%% =========================================================================
fprintf('\n');
fprintf('=====================================================================\n');
fprintf('REQUIRED INTEGRATION TIME AT FIXED STAND-OFF\n');
fprintf('=====================================================================\n');
fprintf('Instrument: %s | SNR = %.1f | rho = %.0f kg/m^3\n', ...
    cfg.instrument_ast, cfg.SNR_target, cfg.rho_kgm3);
fprintf('Ops classes: single-pass < %.0f hr | campaign < %.0f hr\n', ...
    cfg.arc_single_hr, cfg.arc_campaign_hr);
fprintf('=====================================================================\n');

% SU49
fprintf('\n-- 2006 SU49 (D = 377 m) --\n');
fprintf('%10s | %12s | %12s | %12s | %10s | %28s\n', ...
    'h', 'Gamma [E]', 'g [uGal]', 'Treq [hr]', 'Treq [d]', 'Ops class');
fprintf('%s\n', repmat('-', 1, 96));

for i = 1:numel(cfg.h_fixed_list_km)
    h_i = cfg.h_fixed_list_km(i);
    pt_fix = compute_required_time(cfg, instr, 377, h_i, cfg.instrument_ast);
    ops = classify_ops(cfg, pt_fix.T_req_hr, pt_fix.reachable);
    fprintf('%10s | %12.3e | %12.3e | %12.3f | %10.3f | %28s\n', ...
        cfg.h_fixed_labels(i), pt_fix.gradE, pt_fix.g_uGal, ...
        pt_fix.T_req_hr_display, pt_fix.T_req_days_display, ops);
end

% SV19 range
fprintf('\n-- 2017 SV19 (D = 20–60 m range) --\n');
fprintf('%8s | %10s | %12s | %12s | %10s | %28s\n', ...
    'D [m]', 'h', 'Gamma [E]', 'Treq [hr]', 'Treq [d]', 'Ops class');
fprintf('%s\n', repmat('-', 1, 90));

for D_i = D_SV19
    for i = 1:numel(cfg.h_fixed_list_km)
        h_i = cfg.h_fixed_list_km(i);
        pt_fix = compute_required_time(cfg, instr, D_i, h_i, cfg.instrument_ast);
        ops = classify_ops(cfg, pt_fix.T_req_hr, pt_fix.reachable);
        fprintf('%8.1f | %10s | %12.3e | %12.3f | %10.3f | %28s\n', ...
            D_i, cfg.h_fixed_labels(i), pt_fix.gradE, ...
            pt_fix.T_req_hr_display, pt_fix.T_req_days_display, ops);
    end
end

% Interpretation
fprintf('\n-- Interpretation --\n');
fprintf('SU49: GOCE-class gradiometry supports operationally feasible detection\n');
fprintf('  from most stand-off distances considered. Closer passes (<1 km) permit\n');
fprintf('  single-pass detection; wider orbits (5–10 km) require multi-arc campaigns.\n');
fprintf('SV19: practical detection confined to very close proximity (<500 m for\n');
fprintf('  D = 60 m; effectively surface-contact for D = 20 m). Extended cumulative\n');
fprintf('  integration and repeated close passes are required.\n');

%% =========================================================================
%% I) MINIMUM DETECTABLE DIAMETER AT FIXED STAND-OFF
%% =========================================================================
fprintf('\n');
fprintf('=====================================================================\n');
fprintf('MINIMUM DETECTABLE ASTEROID DIAMETER AT FIXED STAND-OFF\n');
fprintf('=====================================================================\n');
fprintf('Instrument: %s | SNR = %.1f | rho = %.0f kg/m^3\n', ...
    cfg.instrument_ast, cfg.SNR_target, cfg.rho_kgm3);
fprintf('=====================================================================\n');
fprintf('%10s | %10s | %14s\n', 'h', 'T_int', 'D_min [m]');
fprintf('%s\n', repmat('-', 1, 40));

for i = 1:numel(cfg.h_fixed_list_km)
    h_i = cfg.h_fixed_list_km(i);
    for j = 1:numel(cfg.T_detect_list_s)
        T_j = cfg.T_detect_list_s(j);
        D_min_m = compute_min_diameter(cfg, instr, h_i, T_j, cfg.instrument_ast);
        fprintf('%10s | %10s | %14.1f\n', ...
            cfg.h_fixed_labels(i), cfg.T_detect_labels(j), D_min_m);
    end
end

fprintf('\nThis table shows the smallest asteroid detectable at each combination\n');
fprintf('of stand-off distance and integration time. Values much smaller than\n');
fprintf('the SV19 range (20–60 m) indicate comfortable margin; values larger\n');
fprintf('indicate that detection is not feasible at that stand-off.\n');

fprintf('=====================================================================\n\n');

%% =========================================================================
%% LOCAL FUNCTIONS
%% =========================================================================

function k = find_instrument(instr, name)
% Look up instrument index by name.
names = string({instr.name});
k = find(strcmp(names, name), 1, 'first');
if isempty(k)
    error('Instrument "%s" not found in database.', name);
end
end

function pt = compute_point(cfg, instr, D_m, h_km, T_int_s, instrument_name)
% Compute field strength, SNR, and required time for a single design point.

k  = find_instrument(instr, instrument_name);
nE = instr(k).nE;

R_m  = D_m / 2;
M_kg = (4/3) * pi * R_m^3 * cfg.rho_kgm3;
r_m  = R_m + h_km * 1000;

g_ms2   = cfg.G * M_kg / r_m^2;
grad_s2 = 2 * g_ms2 / r_m;
gradE   = grad_s2 / cfg.EOTVOS;

SNR_val    = (gradE * sqrt(T_int_s)) / nE;
T_req_s    = ((cfg.SNR_target * nE) / gradE)^2;

pt.instrument_name = instrument_name;
pt.nE         = nE;
pt.D_m        = D_m;
pt.R_m        = R_m;
pt.rho_kgm3   = cfg.rho_kgm3;
pt.h_km       = h_km;
pt.r_m        = r_m;
pt.r_km       = r_m / 1000;
pt.M_kg       = M_kg;
pt.g_ms2      = g_ms2;
pt.g_uGal     = g_ms2 * 1e8;
pt.grad_s2    = grad_s2;
pt.gradE      = gradE;
pt.T_int_s    = T_int_s;
pt.SNR        = SNR_val;
pt.SNR_target = cfg.SNR_target;
pt.T_req_s    = T_req_s;
pt.T_req_hr   = T_req_s / 3600;
pt.T_req_days = T_req_s / 86400;
pt.detectable = (SNR_val >= cfg.SNR_target);
end

function pt = compute_max_offset(cfg, instr, D_m, T_int_s, instrument_name)
% Compute the maximum surface offset at which detection is achieved.

k  = find_instrument(instr, instrument_name);
nE = instr(k).nE;

R_m  = D_m / 2;
M_kg = (4/3) * pi * R_m^3 * cfg.rho_kgm3;

GammaE_thresh   = (cfg.SNR_target_ast * nE) / sqrt(T_int_s);
Gamma_thresh_s2 = GammaE_thresh * cfg.EOTVOS;

r_max_m = (2 * cfg.G * M_kg / Gamma_thresh_s2)^(1/3);
h_max_m = r_max_m - R_m;

if h_max_m < 0
    h_max_m = 0;
    detectable_any = false;
else
    detectable_any = true;
end

pt.D_m             = D_m;
pt.R_m             = R_m;
pt.M_kg            = M_kg;
pt.T_int_s         = T_int_s;
pt.instrument_name = instrument_name;
pt.nE              = nE;
pt.GammaE_thresh   = GammaE_thresh;
pt.r_max_m         = r_max_m;
pt.r_max_km        = r_max_m / 1000;
pt.h_max_m         = h_max_m;
pt.h_max_km        = h_max_m / 1000;
pt.detectable_any  = detectable_any;
end

function pt = compute_required_time(cfg, instr, D_m, h_km, instrument_name)
% Compute required integration time at a fixed stand-off distance.

k  = find_instrument(instr, instrument_name);
nE = instr(k).nE;

R_m  = D_m / 2;
M_kg = (4/3) * pi * R_m^3 * cfg.rho_kgm3;
r_m  = R_m + h_km * 1000;

g_ms2   = cfg.G * M_kg / r_m^2;
grad_s2 = 2 * g_ms2 / r_m;
gradE   = grad_s2 / cfg.EOTVOS;

T_req_s  = ((cfg.SNR_target * nE) / gradE)^2;
T_req_hr = T_req_s / 3600;

reachable = isfinite(T_req_s) && (T_req_s <= cfg.T_cap_s);

if reachable
    pt.T_req_hr_display   = T_req_hr;
    pt.T_req_days_display = T_req_s / 86400;
else
    pt.T_req_hr_display   = NaN;
    pt.T_req_days_display = NaN;
end

pt.D_m        = D_m;
pt.R_m        = R_m;
pt.M_kg       = M_kg;
pt.h_km       = h_km;
pt.r_km       = r_m / 1000;
pt.g_ms2      = g_ms2;
pt.g_uGal     = g_ms2 * 1e8;
pt.grad_s2    = grad_s2;
pt.gradE      = gradE;
pt.T_req_s    = T_req_s;
pt.T_req_hr   = T_req_hr;
pt.T_req_days = T_req_s / 86400;
pt.reachable  = reachable;
pt.instrument_name = instrument_name;
pt.nE         = nE;
end

function D_min_m = compute_min_diameter(cfg, instr, h_km, T_int_s, instrument_name)
% Compute the minimum detectable asteroid diameter at a given offset and
% integration time.
%
% From Gamma = 2*G*M/r^3 with M = (4/3)*pi*R^3*rho and r = R + h:
%   Gamma = (8/3)*pi*G*rho * R^3 / (R + h)^3
%
% For R << h (far-field):  Gamma ~ (8/3)*pi*G*rho * R^3 / h^3
%   => R_min = h * (Gamma_thresh / ((8/3)*pi*G*rho))^(1/3)
%
% For general case we solve numerically using fzero.

k  = find_instrument(instr, instrument_name);
nE = instr(k).nE;

GammaE_thresh   = (cfg.SNR_target * nE) / sqrt(T_int_s);
Gamma_thresh_s2 = GammaE_thresh * cfg.EOTVOS;

h_m   = h_km * 1000;
rho   = cfg.rho_kgm3;
G_val = cfg.G;

% Residual: Gamma(R) - Gamma_thresh = 0
f = @(R) (2 * G_val * (4/3) * pi * R.^3 * rho) ./ (R + h_m).^3 - Gamma_thresh_s2;

% Initial bracket: R from 0.01 m to 1e6 m
try
    R_min = fzero(f, [0.01, 1e6]);
    D_min_m = 2 * R_min;
catch
    D_min_m = NaN;   % no solution in range
end
end

function print_summary(cfg, pt)
% Print the main single-point console dashboard.

fprintf('\n');
fprintf('=====================================================================\n');
fprintf('NEO GRAVITY GRADIOMETRY — SINGLE-POINT SUMMARY\n');
fprintf('=====================================================================\n');

fprintf('\n-- Asteroid and geometry --\n');
fprintf('Diameter:       %.2f m\n', pt.D_m);
fprintf('Radius:         %.2f m\n', pt.R_m);
fprintf('Density:        %.0f kg/m^3\n', pt.rho_kgm3);
fprintf('Mass:           %.3e kg\n', pt.M_kg);
fprintf('Surface offset: %.3f km\n', pt.h_km);
fprintf('Centre distance:%.3f km\n', pt.r_km);

fprintf('\n-- Instrument --\n');
fprintf('Name:           %s\n', pt.instrument_name);
fprintf('Noise density:  %.3g E/sqrt(Hz)\n', pt.nE);
fprintf('Integration:    %.1f s\n', pt.T_int_s);
fprintf('Target SNR:     %.1f\n', pt.SNR_target);

fprintf('\n-- Gravitational field --\n');
fprintf('Acceleration:   %.3e m/s^2  (%.3e uGal)\n', pt.g_ms2, pt.g_uGal);
fprintf('Gradient:       %.3e s^-2  (%.3e E)\n', pt.grad_s2, pt.gradE);

fprintf('\n-- Detection --\n');
fprintf('Achieved SNR:   %.3f\n', pt.SNR);
fprintf('Detectable:     %s\n', passfail(pt.detectable));
fprintf('Required time:  %.3f hr  (%.3f days)\n', pt.T_req_hr, pt.T_req_days);

fprintf('=====================================================================\n\n');
end

function print_orbital_context(cfg, D_m, h_km)
% Print escape speed and approximate orbital period at the reporting offset.

R_m  = D_m / 2;
M_kg = (4/3) * pi * R_m^3 * cfg.rho_kgm3;
r_m  = R_m + h_km * 1000;

mu    = cfg.G * M_kg;
v_esc = sqrt(2 * mu / r_m);
T_orb = 2 * pi * sqrt(r_m^3 / mu);

fprintf('\nOrbital context at h = %.2f km around D = %.0f m:\n', h_km, D_m);
fprintf('  Escape speed:          %.4f m/s  (%.2f cm/s)\n', v_esc, v_esc * 100);
fprintf('  Circular orbit period: %.1f s  (%.2f hr)\n', T_orb, T_orb / 3600);
fprintf('  (Bound orbit requires relative velocity << %.4f m/s)\n', v_esc);
end

function label = classify_ops(cfg, T_req_hr, reachable)
% Heuristic classification of operational feasibility based on cumulative
% integration time.

if ~reachable || ~isfinite(T_req_hr)
    label = 'probably impractical';
elseif T_req_hr <= cfg.arc_single_hr
    label = 'single-pass feasible';
elseif T_req_hr <= cfg.arc_campaign_hr
    label = 'multi-arc feasible';
elseif T_req_hr <= 4 * cfg.arc_campaign_hr
    label = 'operationally challenging';
else
    label = 'probably impractical';
end
end

function s = passfail(x)
if x, s = 'PASS'; else, s = '** FAIL **'; end
end