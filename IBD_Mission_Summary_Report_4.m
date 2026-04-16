%% =========================================================================
%% IBD_Summary_Report_4.m
%% =========================================================================
% IBD Console Summary — single-point dashboard and optional sweep table
%
% Purpose
%   Print a concise numerical summary for a chosen stand-off distance and
%   thruster configuration, including beam geometry, coupling, thrust,
%   power, propellant, and thruster lifetime.  An optional sweep table
%   tabulates the same quantities across a range of stand-off distances
%   for rapid trade studies.
%
% Recommended run order
%   1) IBD_Mission_Master_1.m
%   2) IBD_Thruster_Performance_2.m
%   3) IBD_Summary_Report_4.m        <-- this script
%
% Required external function
%   IBD_compute_point_function.m
%
% Output
%   Console printout only (no figures).
% =========================================================================

clc;

%% =========================================================================
%% A) REPORTING CONFIGURATION
%% =========================================================================
cfg = struct();

% Geometry / asteroid
cfg.theta_deg     = 15;          % beam half-angle [deg]
cfg.R_ast_m       = 30;          % asteroid radius [m]
cfg.rho_kgm3      = 3500;        % bulk density [kg/m^3]
cfg.surface       = 1.0;         % surface momentum-transfer efficiency [0..1]
cfg.incident_deg  = 0;           % beam incidence angle [deg] (0 = normal)

% Mission target
cfg.dv_target_ms  = 3e-3;        % target delta-v [m/s]
cfg.dur_post_yrs  = 5;           % post-burn ballistic drift time [years]

% Stand-off reporting
cfg.d_report_m    = 100;         % single-point stand-off distance [m]
cfg.d_sweep_m     = 100:50:800;  % sweep distances (set [] to disable)

% Beam thruster
cfg.thruster_name = 'NEXT-C';    % 'NEXT-C','T6','SPT-140','BHT-6000','PPS5000'
cfg.T_cmd_mN      = 83;          % commanded thrust per thruster [mN]
cfg.N_beam        = 2;           % number of beam thrusters
cfg.P_cmd_W       = NaN;         % power per beam thruster [W]; NaN => infer from T-P slope

% Counter-thrust
cfg.N_counter             = 2;          % 0 to disable
cfg.counter_factor        = 1.0;        % total counter thrust = factor * total beam thrust
cfg.counter_thruster_name = 'SPT-140';

% Pass/fail thresholds
cfg.max_burn_days = 365;         % maximum allowable burn duration [days]
cfg.max_power_kW  = 8.5;        % maximum allowable total power [kW]

%% =========================================================================
%% B) INHERIT CANONICAL PARAMETERS FROM UPSTREAM SCRIPTS
%% =========================================================================
% Overwrite geometry and mission-target fields with values from
% IBD_Mission_Master_1 if it has been run.  Thruster selection and
% reporting options above are retained.

if exist('IBD','var') && isfield(IBD,'cfg')
    cfg.theta_deg    = IBD.cfg.theta_deg;
    cfg.R_ast_m      = IBD.cfg.R_ast_m;
    cfg.rho_kgm3     = IBD.cfg.rho_kgm3;
    cfg.surface      = IBD.cfg.surface;
    cfg.incident_deg = IBD.cfg.incident_deg;
    cfg.dv_target_ms = IBD.cfg.dv_target_ms;
    cfg.dur_post_yrs = IBD.cfg.dur_post_yrs;
    cfg.N_beam       = IBD.cfg.N_beam;
    cfg.T_cmd_mN     = IBD.cfg.T_beam_mN;
end

%% =========================================================================
%% C) THRUSTER DATABASE
%% =========================================================================
% Build the database struct from IBD.thruster if available (populated by
% IBD_Thruster_Performance_2), otherwise use hardcoded reference values.

db = struct();

if exist('IBD','var') && isfield(IBD,'thruster')
    % Map from thruster name to index in the IBD.thruster arrays
    idx = containers.Map(IBD.thruster.names, num2cell(1:numel(IBD.thruster.names)));
    safe = @(name) strrep(name, '-', '_');

    for i = 1:numel(IBD.thruster.names)
        fn = safe(IBD.thruster.names{i});
        db.isp.(fn)         = IBD.thruster.isp(i);
        db.life_hr.(fn)     = IBD.thruster.life_hr(i);
        db.TP_mN_per_W.(fn) = IBD.thruster.TP_mN_per_W(i);
    end

    db.P_env = IBD.thruster.P_env;
    db.names = IBD.thruster.names;
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

    db.P_env = [];
    db.names = {};
end

%% =========================================================================
%% D) SINGLE-POINT SUMMARY
%% =========================================================================
pt = IBD_compute_point_function(cfg, db, cfg.d_report_m);
ibd_print_summary(cfg, pt);

%% =========================================================================
%% E) OPTIONAL SWEEP TABLE
%% =========================================================================
if ~isempty(cfg.d_sweep_m)
    fprintf('\n');
    fprintf('=====================================================================\n');
    fprintf('IBD SWEEP TABLE (varying stand-off; all other inputs held constant)\n');
    fprintf('=====================================================================\n');

    % Header
    fprintf('%8s | %7s | %9s | %8s | %7s | %8s | %9s | %9s\n', ...
        'd [m]', 'eta', 'T_eff[mN]', 't [d]', 'P [kW]', 'Prop[kg]', ...
        'BeamL [%]', 'CtrL [%]');
    fprintf('%s\n', repmat('-', 1, 82));

    for d_i = cfg.d_sweep_m
        pti = IBD_compute_point_function(cfg, db, d_i);
        fprintf('%8.1f | %7.4f | %9.1f | %8.1f | %7.2f | %8.2f | %9.2f | %9.2f\n', ...
            pti.d_used_m, pti.eta_total, 1e3*pti.T_eff_N, pti.t_days, ...
            pti.P_total_kW, pti.mprop_total_kg, ...
            pti.life_frac_beam, pti.life_frac_counter);
    end

    fprintf('=====================================================================\n\n');
end

%% =========================================================================
%% LOCAL FUNCTIONS
%% =========================================================================

function ibd_print_summary(cfg, pt)
% Print the main single-point console dashboard.

fprintf('\n');
fprintf('=====================================================================\n');
fprintf('IBD CONSOLE SUMMARY — SINGLE DESIGN POINT\n');
fprintf('=====================================================================\n');

% --- Inputs
fprintf('\n-- Asteroid and geometry --\n');
fprintf('Asteroid:       R = %.1f m  (D = %.1f m),  rho = %.0f kg/m^3,  m = %.3e kg\n', ...
    cfg.R_ast_m, 2*cfg.R_ast_m, cfg.rho_kgm3, pt.m_ast_kg);
fprintf('Stand-off:      d = %.2f m\n', pt.d_used_m);
fprintf('Beam half-angle: %.2f deg\n', cfg.theta_deg);

fprintf('\nCoupling:  eta_geom = %.4f,  surface = %.2f,  cos(incidence) = %.4f\n', ...
    pt.eta_geom, cfg.surface, cosd(cfg.incident_deg));
fprintf('           eta_total = %.4f\n', pt.eta_total);

fprintf('\nTarget:    dv = %.3g m/s,  post-IBD drift = %.1f years\n', ...
    cfg.dv_target_ms, cfg.dur_post_yrs);

% --- Thruster configuration
fprintf('\n-- Thruster configuration --\n');
fprintf('Beam:     %s  x%d,  T_cmd = %.1f mN per thruster\n', ...
    cfg.thruster_name, cfg.N_beam, cfg.T_cmd_mN);
if cfg.N_counter > 0
    fprintf('Counter:  %s  x%d,  factor = %.2f\n', ...
        cfg.counter_thruster_name, cfg.N_counter, cfg.counter_factor);
end

% --- Derived outputs
fprintf('\n-- Beam footprint --\n');
fprintf('r_beam = %.2f m,  A_beam = %.3g m^2,  A_ast = %.3g m^2\n', ...
    pt.r_beam_m, pt.A_beam_m2, pt.A_ast_m2);

fprintf('\n-- Thrust and time --\n');
fprintf('Produced thrust (beam total): %.5f N\n', pt.T_total_N);
fprintf('Effective thrust on asteroid: %.5e N  (%.2f mN)\n', pt.T_eff_N, 1e3*pt.T_eff_N);
fprintf('Time to impart target dv:     %.2f days  (%.4f years)\n', pt.t_days, pt.t_yrs);

% --- Power
fprintf('\n-- Power budget --\n');
fprintf('Beam power:    %.2f kW  (%.0f W each x%d)\n', ...
    pt.P_beam_total_kW, pt.P_cmd_W, cfg.N_beam);
if cfg.N_counter > 0
    fprintf('Counter power: %.2f kW  (%.0f W each x%d)\n', ...
        pt.P_counter_total_kW, pt.P_counter_cmd_W, cfg.N_counter);
end
fprintf('TOTAL power:   %.2f kW\n', pt.P_total_kW);

% --- Propellant and lifetime
fprintf('\n-- Propellant and thruster lifetime --\n');
fprintf('Beam:    mdot = %.3e kg/s,  propellant = %.2f kg,  lifetime used = %.2f %%\n', ...
    pt.mdot_beam_kgps, pt.mprop_beam_kg, pt.life_frac_beam);
if cfg.N_counter > 0
    fprintf('Counter: mdot = %.3e kg/s,  propellant = %.2f kg,  lifetime used = %.2f %%\n', ...
        pt.mdot_counter_kgps, pt.mprop_counter_kg, pt.life_frac_counter);
end
fprintf('TOTAL propellant: %.2f kg\n', pt.mprop_total_kg);

% --- Pass/fail checks
fprintf('\n-- Design checks --\n');
fprintf('Coupling > 0:                   %s\n', passfail(pt.eta_total > 0));
fprintf('Beam lifetime OK:               %s\n', passfail(pt.life_ok_beam));
if cfg.N_counter > 0
    fprintf('Counter lifetime OK:            %s\n', passfail(pt.life_ok_counter));
end
fprintf('Burn duration <= %d days:       %s  (%.1f days)\n', ...
    cfg.max_burn_days, passfail(pt.t_days <= cfg.max_burn_days), pt.t_days);
fprintf('Total power   <= %.1f kW:        %s  (%.2f kW)\n', ...
    cfg.max_power_kW, passfail(pt.P_total_kW <= cfg.max_power_kW), pt.P_total_kW);

if ~isnan(pt.Pmin_W)
    fprintf('Power envelope: %.0f–%.0f W,  P_cmd = %.0f W:  %s\n', ...
        pt.Pmin_W, pt.Pmax_W, pt.P_cmd_W, passfail(pt.power_ok));
else
    fprintf('Power envelope: data not available (P_cmd inferred from T-P slope)\n');
end

fprintf('=====================================================================\n\n');
end

function s = passfail(condition)
% Return a PASS/FAIL string for console display.
if condition
    s = 'PASS';
else
    s = '** FAIL **';
end
end