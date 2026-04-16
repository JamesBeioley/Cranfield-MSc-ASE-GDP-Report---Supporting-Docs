%% =========================================================================
%% IBD_Phasing_Propellant_5.m
%% =========================================================================
% Phasing-Orbit Propellant and Thruster Lifetime Calculator
%
% Purpose
%   Estimate the propellant consumed and thruster lifetime fraction used
%   during an electric-propulsion phasing or transfer segment (e.g. the
%   cruise to a second asteroid target).  Supports a main thruster bank
%   with an optional counter-thrust configuration.
%
% Assumptions
%   - Constant thrust and constant power over the segment duration.
%   - Propellant consumption is computed from the Tsiolkovsky relation
%     in the low-delta-v / constant-mass-flow limit:  m_prop = mdot * t.
%   - No gravitational or finite-burn losses are included; the result is
%     a first-order ideal estimate.
%
% Recommended run order
%   1) IBD_Mission_Master_1.m         (optional — not required)
%   2) IBD_Thruster_Performance_2.m   (provides thruster database)
%   3) IBD_Phasing_Propellant_5.m     <-- this script
%
% Output
%   PHASE struct in workspace + console summary.
% =========================================================================

%% =========================================================================
%% A) USER INPUTS
%% =========================================================================
cfg = struct();

% Main phasing thrusters
cfg.thruster_name = 'NEXT-C';       % 'NEXT-C','T6','SPT-140','BHT-6000','PPS5000'
cfg.N_thrusters   = 2;              % number of active phasing thrusters

% Specify EITHER power OR thrust per thruster (set the other to NaN).
% If both are specified, thrust takes priority.
cfg.P_cmd_W       = 4500;           % commanded power per thruster [W]
cfg.T_cmd_mN      = NaN;            % commanded thrust per thruster [mN]

% Segment duration
cfg.t_phase_days  = 100;            % phasing burn duration [days]

% Optional counter-thrust
%   Thrust priority: T_counter_mN > P_counter_W > counter_factor.
%   Set the preferred input; leave the others as NaN.
cfg.use_counter    = false;
cfg.counter_name   = 'SPT-140';
cfg.N_counter      = 1;
cfg.counter_factor = 1.0;           % total counter thrust = factor * main total thrust
cfg.P_counter_W    = NaN;           % power per counter thruster [W]
cfg.T_counter_mN   = NaN;           % thrust per counter thruster [mN]

%% =========================================================================
%% B) THRUSTER DATABASE
%% =========================================================================
g0 = 9.81;

db = struct();

if exist('IBD','var') && isfield(IBD,'thruster')
    safe = @(name) strrep(name, '-', '_');
    for i = 1:numel(IBD.thruster.names)
        fn = safe(IBD.thruster.names{i});
        db.isp.(fn)         = IBD.thruster.isp(i);
        db.life_hr.(fn)     = IBD.thruster.life_hr(i);
        db.TP_mN_per_W.(fn) = IBD.thruster.TP_mN_per_W(i);
    end
else
    % Hardcoded reference values (used only if Script 2 has not been run)
    db.isp.NEXT_C   = 3350;    db.isp.T6       = 4000;
    db.isp.SPT_140  = 1650;    db.isp.BHT_6000 = 1870;
    db.isp.PPS5000  = 1780;

    db.life_hr.NEXT_C   = 50000;   db.life_hr.T6       = 20000;
    db.life_hr.SPT_140  = 15000;   db.life_hr.BHT_6000 = 15000;
    db.life_hr.PPS5000  = 20000;

    db.TP_mN_per_W.NEXT_C   = 0.033;  db.TP_mN_per_W.T6       = 0.03;
    db.TP_mN_per_W.SPT_140  = 0.06;   db.TP_mN_per_W.BHT_6000 = 0.06;
    db.TP_mN_per_W.PPS5000  = 0.05;
end

%% =========================================================================
%% C) MAIN PHASING THRUSTERS
%% =========================================================================
key = strrep(cfg.thruster_name, '-', '_');

Isp_main  = db.isp.(key);
life_main = db.life_hr.(key);
TP_main   = db.TP_mN_per_W.(key);

% Resolve thrust / power (thrust takes priority if both are specified)
if ~isnan(cfg.T_cmd_mN)
    T_cmd_mN = cfg.T_cmd_mN;
    P_cmd_W  = T_cmd_mN / max(TP_main, 1e-12);
else
    P_cmd_W  = cfg.P_cmd_W;
    T_cmd_mN = TP_main * P_cmd_W;
end

T_total_main_N = (T_cmd_mN * 1e-3) * cfg.N_thrusters;   % total thrust [N]
mdot_main_kgps = T_total_main_N / (g0 * Isp_main);       % mass flow [kg/s]

t_phase_s  = cfg.t_phase_days * 86400;
t_phase_hr = t_phase_s / 3600;

mprop_main_kg = mdot_main_kgps * t_phase_s;
life_main_pct = 100 * (t_phase_hr / max(life_main, 1e-12));

%% =========================================================================
%% D) OPTIONAL COUNTER-THRUSTERS
%% =========================================================================
% Thrust specification priority:
%   1) Direct thrust (T_counter_mN)
%   2) Direct power  (P_counter_W), thrust inferred via T-P slope
%   3) Factor of main total thrust (counter_factor)

counter = struct();
counter.used = cfg.use_counter;

if cfg.use_counter
    ckey  = strrep(cfg.counter_name, '-', '_');
    Isp_c = db.isp.(ckey);
    life_c = db.life_hr.(ckey);
    TP_c  = db.TP_mN_per_W.(ckey);

    if ~isnan(cfg.T_counter_mN)
        % Priority 1: direct thrust specification
        T_ctr_mN_each = cfg.T_counter_mN;
        P_ctr_W_each  = T_ctr_mN_each / max(TP_c, 1e-12);
    elseif ~isnan(cfg.P_counter_W)
        % Priority 2: direct power specification
        P_ctr_W_each  = cfg.P_counter_W;
        T_ctr_mN_each = TP_c * P_ctr_W_each;
    else
        % Priority 3: factor of main total thrust
        T_ctr_total_N = cfg.counter_factor * T_total_main_N;
        T_ctr_mN_each = 1e3 * T_ctr_total_N / max(cfg.N_counter, 1);
        P_ctr_W_each  = T_ctr_mN_each / max(TP_c, 1e-12);
    end

    T_ctr_total_N     = (T_ctr_mN_each * 1e-3) * cfg.N_counter;
    mdot_counter_kgps = T_ctr_total_N / (g0 * Isp_c);
    mprop_counter_kg  = mdot_counter_kgps * t_phase_s;
    life_counter_pct  = 100 * (t_phase_hr / max(life_c, 1e-12));

    counter.name          = cfg.counter_name;
    counter.N             = cfg.N_counter;
    counter.Isp_s         = Isp_c;
    counter.life_hr       = life_c;
    counter.TP_mN_per_W   = TP_c;
    counter.T_cmd_mN_each = T_ctr_mN_each;
    counter.P_cmd_W_each  = P_ctr_W_each;
    counter.T_total_N     = T_ctr_total_N;
    counter.mdot_kgps     = mdot_counter_kgps;
    counter.mprop_kg      = mprop_counter_kg;
    counter.life_used_pct = life_counter_pct;
else
    counter.name          = '';
    counter.N             = 0;
    counter.Isp_s         = NaN;
    counter.life_hr       = NaN;
    counter.TP_mN_per_W   = NaN;
    counter.T_cmd_mN_each = 0;
    counter.P_cmd_W_each  = 0;
    counter.T_total_N     = 0;
    counter.mdot_kgps     = 0;
    counter.mprop_kg      = 0;
    counter.life_used_pct = 0;
end

%% =========================================================================
%% E) TOTALS
%% =========================================================================
total = struct();
total.mprop_kg = mprop_main_kg + counter.mprop_kg;
total.power_kW = (cfg.N_thrusters * P_cmd_W + counter.N * counter.P_cmd_W_each) / 1000;
total.thrust_N = T_total_main_N + counter.T_total_N;

%% =========================================================================
%% F) EXPORT RESULTS
%% =========================================================================
PHASE = struct();
PHASE.cfg = cfg;

PHASE.main.name          = cfg.thruster_name;
PHASE.main.N             = cfg.N_thrusters;
PHASE.main.Isp_s         = Isp_main;
PHASE.main.life_hr       = life_main;
PHASE.main.TP_mN_per_W   = TP_main;
PHASE.main.T_cmd_mN_each = T_cmd_mN;
PHASE.main.P_cmd_W_each  = P_cmd_W;
PHASE.main.T_total_N     = T_total_main_N;
PHASE.main.mdot_kgps     = mdot_main_kgps;
PHASE.main.mprop_kg      = mprop_main_kg;
PHASE.main.life_used_pct = life_main_pct;

PHASE.counter = counter;
PHASE.total   = total;

%% =========================================================================
%% G) CONSOLE SUMMARY
%% =========================================================================
fprintf('\n');
fprintf('=====================================================================\n');
fprintf('PHASING-ORBIT PROPELLANT AND THRUSTER LIFETIME SUMMARY\n');
fprintf('=====================================================================\n');

fprintf('\n-- Segment --\n');
fprintf('Duration:    %.2f days  (%.1f hr)\n', cfg.t_phase_days, t_phase_hr);

fprintf('\n-- Main phasing thrusters --\n');
fprintf('Thruster:    %s  x%d\n', cfg.thruster_name, cfg.N_thrusters);
fprintf('Isp:         %.0f s\n', Isp_main);
fprintf('Lifetime:    %.0f hr per thruster\n', life_main);
fprintf('T-P slope:   %.1f mN/kW\n', 1000*TP_main);
fprintf('Thrust cmd:  %.2f mN per thruster  =>  total %.5f N\n', T_cmd_mN, T_total_main_N);
fprintf('Power cmd:   %.1f W per thruster\n', P_cmd_W);
fprintf('Mass flow:   %.3e kg/s\n', mdot_main_kgps);
fprintf('Propellant:  %.3f kg\n', mprop_main_kg);
fprintf('Lifetime:    %.2f %% used per thruster\n', life_main_pct);

if cfg.use_counter
    fprintf('\n-- Counter-thrusters --\n');
    fprintf('Thruster:    %s  x%d\n', counter.name, counter.N);
    fprintf('Isp:         %.0f s\n', counter.Isp_s);
    fprintf('Lifetime:    %.0f hr per thruster\n', counter.life_hr);
    fprintf('T-P slope:   %.1f mN/kW\n', 1000*counter.TP_mN_per_W);
    fprintf('Thrust cmd:  %.2f mN per thruster  =>  total %.5f N\n', ...
        counter.T_cmd_mN_each, counter.T_total_N);
    fprintf('Power cmd:   %.1f W per thruster\n', counter.P_cmd_W_each);
    fprintf('Mass flow:   %.3e kg/s\n', counter.mdot_kgps);
    fprintf('Propellant:  %.3f kg\n', counter.mprop_kg);
    fprintf('Lifetime:    %.2f %% used per thruster\n', counter.life_used_pct);
end

fprintf('\n-- Totals --\n');
fprintf('Total thrust:     %.5f N\n', total.thrust_N);
fprintf('Total power:      %.3f kW\n', total.power_kW);
fprintf('Total propellant: %.3f kg\n', total.mprop_kg);

fprintf('=====================================================================\n\n');