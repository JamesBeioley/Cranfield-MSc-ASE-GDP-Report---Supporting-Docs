%% =========================================================================
%% IBD_Plume_Surface_6.m
%% =========================================================================
% First-Order IBD Plume–Surface Interaction Model
%
% Purpose
%   Estimate the surface effects of the ion beam on the asteroid:
%     1) Atomic sputtering rate and cumulative sputtered mass
%     2) Whether beam pressure exceeds regolith cohesion thresholds
%        (simple dust-lifting screen)
%     3) Whether sputtered particles exceed asteroid escape speed
%     4) Spacecraft contamination: back-sputtered particle flux and
%        cumulative mass/film deposition on the beam-facing spacecraft face
%
% Model approach
%   - Atomic sputtering is parameterised by an effective sputter yield
%     Y [ejected target atoms per incident ion], evaluated at low, nominal,
%     and high values to bracket the uncertainty.
%   - Bulk dust lifting is treated as a separate pressure-vs-cohesion
%     screen (not a sputtering process).
%   - This is a first-order engineering model, not a full Monte Carlo or
%     binary-collision (TRIM/SDTrimSP) simulation.
%
% Assumptions
%   - Ion velocity is approximated as the effective exhaust velocity
%     v_ion = g0 * Isp.  This is conservative for sputtering estimates
%     because it underestimates the true beam ion kinetic energy (which
%     for a gridded ion engine is set by the screen-grid voltage).
%   - Uniform beam intensity across the cone cross-section.
%   - Sputtered particles leave with a cosine (Lambertian) angular
%     distribution about the surface normal.  For a beam at normal
%     incidence the spacecraft sits approximately on-axis, receiving the
%     peak of the distribution.
%   - Spacecraft contamination is estimated in the far-field limit
%     (illuminated patch treated as a point source at distance d).
%     The fraction of sputtered flux intercepted by the spacecraft is
%     A_sc / (pi * d^2), from integrating the cosine distribution.
%
% Recommended run order
%   1) IBD_Mission_Master_1.m
%   2) IBD_Thruster_Performance_2.m
%   3) IBD_Summary_Report_4.m         (optional)
%   4) IBD_Plume_Surface_6.m          <-- this script
%
% Required external function
%   IBD_compute_point_function.m
%
% Output
%   EJECTA struct in workspace, console summary, eight diagnostic figures.
% =========================================================================

% clc;

%% =========================================================================
%% A) USER INPUTS
%% =========================================================================
cfg_sput = struct();

% Stand-off distances to evaluate [m]
cfg_sput.d_sweep_m  = [10:10:90, 100:50:800];

% Distances reported in the console summary [m]
cfg_sput.d_report_m = [10 50 100 200 500];

% Stand-off distance for instrument contamination assessment [m]
cfg_sput.d_assess_m = 100;

% ---- Ion beam and target material ----

% Ion species mass [amu] — Xe+ for all shortlisted thrusters
cfg_sput.m_ion_amu = 131.29;

% Mean mass of sputtered surface particle [amu]
% ~30 amu is representative of a silicate-like target (e.g. MgSiO3)
cfg_sput.m_target_amu = 30.0;

% Effective sputter yield [ejected atoms per incident ion]
cfg_sput.Y_low  = 0.05;
cfg_sput.Y_nom  = 0.30;
cfg_sput.Y_high = 1.00;

% Characteristic sputtered-particle energies [eV]
cfg_sput.E_sput_low_eV  = 1;
cfg_sput.E_sput_nom_eV  = 5;
cfg_sput.E_sput_high_eV = 10;

% Cohesion thresholds for the dust-lifting screen [Pa]
cfg_sput.cohesion_Pa = [0.1 1 10];

% Ballistic flight times for travel-distance reporting [s]
cfg_sput.t_flight_s = [1 10 100];

% ---- Spacecraft contamination assessment ----
% Cross-sectional area of the spacecraft face exposed to the asteroid
% during IBD operations [m^2].
cfg_sput.A_sc_m2 = 2.3 * 3.0;           % 2.3 m x 3.0 m = 6.9 m^2

% Assumed density of a deposited silicate-like film [kg/m^3].
% Used to convert mass deposition rate into an equivalent film thickness.
cfg_sput.rho_film_kgm3 = 3500;

%% =========================================================================
%% B) INHERIT MISSION / THRUSTER CONFIGURATION
%% =========================================================================
% Pull the IBD mission configuration from upstream scripts if available.

if exist('IBD','var') && isfield(IBD,'cfg')
    cfg_local = struct();

    % Geometry and mission targets (always present in IBD.cfg)
    cfg_local.theta_deg    = IBD.cfg.theta_deg;
    cfg_local.R_ast_m      = IBD.cfg.R_ast_m;
    cfg_local.rho_kgm3     = IBD.cfg.rho_kgm3;
    cfg_local.surface      = IBD.cfg.surface;
    cfg_local.incident_deg = IBD.cfg.incident_deg;
    cfg_local.dv_target_ms = IBD.cfg.dv_target_ms;
    cfg_local.dur_post_yrs = IBD.cfg.dur_post_yrs;
    cfg_local.N_beam       = IBD.cfg.N_beam;
    cfg_local.T_cmd_mN     = IBD.cfg.T_beam_mN;

    % Thruster selection: prefer cfg from Script 4 if available, else defaults
    if exist('cfg','var') && isfield(cfg,'counter_thruster_name')
        cfg_local.thruster_name         = cfg.thruster_name;
        cfg_local.P_cmd_W               = cfg.P_cmd_W;
        cfg_local.N_counter             = cfg.N_counter;
        cfg_local.counter_factor        = cfg.counter_factor;
        cfg_local.counter_thruster_name = cfg.counter_thruster_name;
    else
        cfg_local.thruster_name         = 'NEXT-C';
        cfg_local.P_cmd_W               = NaN;
        cfg_local.N_counter             = 0;
        cfg_local.counter_factor        = 1.0;
        cfg_local.counter_thruster_name = 'SPT-140';
    end

elseif exist('cfg','var') && isfield(cfg,'theta_deg')
    % Accept the cfg struct from IBD_Summary_Report_4 if present
    cfg_local = cfg;

else
    % Standalone fallback
    cfg_local = struct();
    cfg_local.theta_deg             = 15;
    cfg_local.R_ast_m               = 30;
    cfg_local.rho_kgm3              = 2500;
    cfg_local.surface               = 1.0;
    cfg_local.incident_deg          = 0;
    cfg_local.dv_target_ms          = 3e-3;
    cfg_local.dur_post_yrs          = 5;
    cfg_local.thruster_name         = 'NEXT-C';
    cfg_local.T_cmd_mN              = 85;
    cfg_local.N_beam                = 2;
    cfg_local.P_cmd_W               = NaN;
    cfg_local.N_counter             = 0;
    cfg_local.counter_factor        = 1.0;
    cfg_local.counter_thruster_name = 'SPT-140';
end

%% =========================================================================
%% C) THRUSTER DATABASE
%% =========================================================================
if exist('IBD','var') && isfield(IBD,'thruster')
    db = struct();
    safe = @(name) strrep(name, '-', '_');
    for i = 1:numel(IBD.thruster.names)
        fn = safe(IBD.thruster.names{i});
        db.isp.(fn)         = IBD.thruster.isp(i);
        db.life_hr.(fn)     = IBD.thruster.life_hr(i);
        db.TP_mN_per_W.(fn) = IBD.thruster.TP_mN_per_W(i);
    end
    db.P_env = IBD.thruster.P_env;
    db.names = IBD.thruster.names;

elseif ~exist('db','var')
    db = struct();
    db.isp.NEXT_C   = 3350;    db.isp.T6       = 4000;
    db.isp.SPT_140  = 1650;    db.isp.BHT_6000 = 1870;
    db.isp.PPS5000  = 1780;

    db.life_hr.NEXT_C   = 50000;   db.life_hr.T6       = 20000;
    db.life_hr.SPT_140  = 15000;   db.life_hr.BHT_6000 = 15000;
    db.life_hr.PPS5000  = 20000;

    db.TP_mN_per_W.NEXT_C   = 0.033;  db.TP_mN_per_W.T6       = 0.03;
    db.TP_mN_per_W.SPT_140  = 0.06;   db.TP_mN_per_W.BHT_6000 = 0.06;
    db.TP_mN_per_W.PPS5000  = 0.05;

    db.P_env = [];   db.names = {};
end

%% =========================================================================
%% D) PHYSICAL CONSTANTS
%% =========================================================================
amu = 1.66053906660e-27;        % atomic mass unit [kg]
g0  = 9.81;                     % standard gravity [m/s^2]
eV  = 1.602176634e-19;          % elementary charge / eV-to-J conversion [C / J/eV]
G   = 6.67430e-11;              % gravitational constant [m^3 kg^-1 s^-2]

m_ion_kg    = cfg_sput.m_ion_amu    * amu;
m_target_kg = cfg_sput.m_target_amu * amu;

thr_key = strrep(cfg_local.thruster_name, '-', '_');
Isp_s   = db.isp.(thr_key);

%% =========================================================================
%% E) ASTEROID GRAVITY AND ESCAPE SPEED
%% =========================================================================
R_ast = cfg_local.R_ast_m;
rho   = cfg_local.rho_kgm3;

m_ast_kg  = (4/3) * pi * rho * R_ast^3;
mu_ast    = G * m_ast_kg;
g_ast_ms2 = mu_ast / R_ast^2;
v_esc_ms  = sqrt(2 * mu_ast / R_ast);

%% =========================================================================
%% F) SPUTTERED-PARTICLE SPEED ESTIMATES
%% =========================================================================
% Convert characteristic sputtered-particle energies to speeds.

v_sput_low_ms  = sqrt(2 * cfg_sput.E_sput_low_eV  * eV / m_target_kg);
v_sput_nom_ms  = sqrt(2 * cfg_sput.E_sput_nom_eV  * eV / m_target_kg);
v_sput_high_ms = sqrt(2 * cfg_sput.E_sput_high_eV * eV / m_target_kg);

% Free-flight travel distances at characteristic speeds
range_low_m  = v_sput_low_ms  .* cfg_sput.t_flight_s;
range_nom_m  = v_sput_nom_ms  .* cfg_sput.t_flight_s;
range_high_m = v_sput_high_ms .* cfg_sput.t_flight_s;

%% =========================================================================
%% G) PREALLOCATE OUTPUT ARRAYS
%% =========================================================================
Nd = numel(cfg_sput.d_sweep_m);

d_m            = zeros(Nd, 1);
r_beam_m       = zeros(Nd, 1);
A_beam_m2      = zeros(Nd, 1);
A_ast_m2       = zeros(Nd, 1);
eta_geom       = zeros(Nd, 1);

T_total_N      = zeros(Nd, 1);
T_eff_N        = zeros(Nd, 1);
t_req_s        = zeros(Nd, 1);
t_days         = zeros(Nd, 1);

v_ion_ms       = zeros(Nd, 1);
E_ion_eV       = zeros(Nd, 1);
Ndot_ion_total = zeros(Nd, 1);
Ndot_ion_hit   = zeros(Nd, 1);
Gamma_ion_m2s  = zeros(Nd, 1);
P_beam_Pa      = zeros(Nd, 1);

mdot_low_kgps  = zeros(Nd, 1);
mdot_nom_kgps  = zeros(Nd, 1);
mdot_high_kgps = zeros(Nd, 1);

mdot_low_gday  = zeros(Nd, 1);
mdot_nom_gday  = zeros(Nd, 1);
mdot_high_gday = zeros(Nd, 1);

M_low_kg       = zeros(Nd, 1);
M_nom_kg       = zeros(Nd, 1);
M_high_kg      = zeros(Nd, 1);

% Spacecraft contamination arrays
Ndot_sc_low    = zeros(Nd, 1);   % sputtered particle rate at S/C [1/s]
Ndot_sc_nom    = zeros(Nd, 1);
Ndot_sc_high   = zeros(Nd, 1);

mdot_sc_low_kgps  = zeros(Nd, 1);  % mass deposition rate on S/C [kg/s]
mdot_sc_nom_kgps  = zeros(Nd, 1);
mdot_sc_high_kgps = zeros(Nd, 1);

M_sc_low_kg    = zeros(Nd, 1);   % cumulative deposited mass over burn [kg]
M_sc_nom_kg    = zeros(Nd, 1);
M_sc_high_kg   = zeros(Nd, 1);

film_rate_low_nm_day  = zeros(Nd, 1);  % equivalent film growth rate [nm/day]
film_rate_nom_nm_day  = zeros(Nd, 1);
film_rate_high_nm_day = zeros(Nd, 1);

film_total_low_um  = zeros(Nd, 1);   % cumulative film thickness over burn [um]
film_total_nom_um  = zeros(Nd, 1);
film_total_high_um = zeros(Nd, 1);

t_transit_nom_ms = zeros(Nd, 1);     % transit time at nominal sputtered speed [ms]

%% =========================================================================
%% H) MAIN STAND-OFF SWEEP
%% =========================================================================
for i = 1:Nd

    pt = IBD_compute_point_function(cfg_local, db, cfg_sput.d_sweep_m(i));

    d_m(i)       = pt.d_used_m;
    r_beam_m(i)  = pt.r_beam_m;
    A_beam_m2(i) = pt.A_beam_m2;
    A_ast_m2(i)  = pt.A_ast_m2;
    eta_geom(i)  = pt.eta_geom;

    T_total_N(i) = pt.T_total_N;
    T_eff_N(i)   = pt.T_eff_N;
    t_req_s(i)   = pt.t_req_s;
    t_days(i)    = pt.t_days;

    % Ion velocity (effective exhaust velocity; conservative estimate)
    v_ion_ms(i) = g0 * Isp_s;

    % Equivalent ion kinetic energy
    E_ion_eV(i) = 0.5 * m_ion_kg * v_ion_ms(i)^2 / eV;

    % Total ion emission rate from beam thrusters
    Ndot_ion_total(i) = T_total_N(i) / (m_ion_kg * v_ion_ms(i));

    % Ion rate intercepted by the asteroid
    Ndot_ion_hit(i) = eta_geom(i) * Ndot_ion_total(i);

    % Local ion flux on the illuminated asteroid surface [ions/m^2/s]
    % Under the uniform-beam assumption the local flux is the same in both
    % regimes (beam smaller or larger than asteroid): Ndot_total / A_beam.
    Gamma_ion_m2s(i) = Ndot_ion_total(i) / max(A_beam_m2(i), 1e-12);

    % Average beam momentum-flux pressure on the surface [Pa]
    P_beam_Pa(i) = T_total_N(i) / max(A_beam_m2(i), 1e-12);

    % ---- Sputtering ----
    % Total sputtered mass rate = Y * (ions hitting per second) * m_target
    mdot_low_kgps(i)  = cfg_sput.Y_low  * Ndot_ion_hit(i) * m_target_kg;
    mdot_nom_kgps(i)  = cfg_sput.Y_nom  * Ndot_ion_hit(i) * m_target_kg;
    mdot_high_kgps(i) = cfg_sput.Y_high * Ndot_ion_hit(i) * m_target_kg;

    mdot_low_gday(i)  = mdot_low_kgps(i)  * 1000 * 86400;
    mdot_nom_gday(i)  = mdot_nom_kgps(i)  * 1000 * 86400;
    mdot_high_gday(i) = mdot_high_kgps(i) * 1000 * 86400;

    % Cumulative sputtered mass over the burn required to achieve target dv
    M_low_kg(i)  = mdot_low_kgps(i)  * t_req_s(i);
    M_nom_kg(i)  = mdot_nom_kgps(i)  * t_req_s(i);
    M_high_kg(i) = mdot_high_kgps(i) * t_req_s(i);

    % ---- Spacecraft contamination ----
    % Sputtered particles follow a cosine (Lambertian) distribution about
    % the surface normal.  The spacecraft is approximately on-axis at
    % distance d.  In the far-field limit, the differential intensity at
    % theta = 0 is Ndot_sput / pi, and the flux at the spacecraft is
    % Ndot_sput / (pi * d^2).  The rate intercepted by the spacecraft is
    % then Ndot_sput * A_sc / (pi * d^2).

    d_safe_i = max(d_m(i), 1e-6);
    A_sc     = cfg_sput.A_sc_m2;
    rho_film = cfg_sput.rho_film_kgm3;

    % Total sputtered particle rate [1/s] (same as Ndot_ion_hit * Y)
    Ndot_sput_low  = cfg_sput.Y_low  * Ndot_ion_hit(i);
    Ndot_sput_nom  = cfg_sput.Y_nom  * Ndot_ion_hit(i);
    Ndot_sput_high = cfg_sput.Y_high * Ndot_ion_hit(i);

    % Fraction intercepted by spacecraft (cosine distribution, on-axis)
    f_sc = A_sc / (pi * d_safe_i^2);

    % Particle rate arriving at spacecraft [1/s]
    Ndot_sc_low(i)  = Ndot_sput_low  * f_sc;
    Ndot_sc_nom(i)  = Ndot_sput_nom  * f_sc;
    Ndot_sc_high(i) = Ndot_sput_high * f_sc;

    % Mass deposition rate on spacecraft [kg/s]
    mdot_sc_low_kgps(i)  = Ndot_sc_low(i)  * m_target_kg;
    mdot_sc_nom_kgps(i)  = Ndot_sc_nom(i)  * m_target_kg;
    mdot_sc_high_kgps(i) = Ndot_sc_high(i) * m_target_kg;

    % Cumulative deposited mass over the full burn [kg]
    M_sc_low_kg(i)  = mdot_sc_low_kgps(i)  * t_req_s(i);
    M_sc_nom_kg(i)  = mdot_sc_nom_kgps(i)  * t_req_s(i);
    M_sc_high_kg(i) = mdot_sc_high_kgps(i) * t_req_s(i);

    % Equivalent uniform film growth rate [nm/day]
    %   thickness_rate = mdot_sc / (rho_film * A_sc)  [m/s]
    film_rate_low_nm_day(i)  = (mdot_sc_low_kgps(i)  / (rho_film * A_sc)) * 86400 * 1e9;
    film_rate_nom_nm_day(i)  = (mdot_sc_nom_kgps(i)  / (rho_film * A_sc)) * 86400 * 1e9;
    film_rate_high_nm_day(i) = (mdot_sc_high_kgps(i) / (rho_film * A_sc)) * 86400 * 1e9;

    % Cumulative film thickness over the burn [um]
    film_total_low_um(i)  = (M_sc_low_kg(i)  / (rho_film * A_sc)) * 1e6;
    film_total_nom_um(i)  = (M_sc_nom_kg(i)  / (rho_film * A_sc)) * 1e6;
    film_total_high_um(i) = (M_sc_high_kg(i) / (rho_film * A_sc)) * 1e6;

    % Transit time from surface to spacecraft at nominal sputtered speed [ms]
    t_transit_nom_ms(i) = (d_safe_i / v_sput_nom_ms) * 1000;

end

%% =========================================================================
%% I) DUST-LIFTING SCREEN
%% =========================================================================
% Separate from sputtering.  Simple check of whether beam momentum-flux
% pressure exceeds assumed regolith cohesion thresholds.

Pcoh = cfg_sput.cohesion_Pa;

dust_lift = struct();
dust_lift.gt_0p1Pa = P_beam_Pa > Pcoh(1);
dust_lift.gt_1Pa   = P_beam_Pa > Pcoh(2);
dust_lift.gt_10Pa  = P_beam_Pa > Pcoh(3);

%% =========================================================================
%% J) PACK OUTPUT STRUCT
%% =========================================================================
EJECTA = struct();
EJECTA.cfg = cfg_sput;

EJECTA.m_ast_kg   = m_ast_kg;
EJECTA.mu_ast     = mu_ast;
EJECTA.g_ast_ms2  = g_ast_ms2;
EJECTA.v_esc_ms   = v_esc_ms;

EJECTA.v_sput_low_ms  = v_sput_low_ms;
EJECTA.v_sput_nom_ms  = v_sput_nom_ms;
EJECTA.v_sput_high_ms = v_sput_high_ms;
EJECTA.range_low_m    = range_low_m;
EJECTA.range_nom_m    = range_nom_m;
EJECTA.range_high_m   = range_high_m;

EJECTA.d_m            = d_m;
EJECTA.r_beam_m       = r_beam_m;
EJECTA.A_beam_m2      = A_beam_m2;
EJECTA.A_ast_m2       = A_ast_m2;
EJECTA.eta_geom       = eta_geom;

EJECTA.T_total_N      = T_total_N;
EJECTA.T_eff_N        = T_eff_N;
EJECTA.t_req_s        = t_req_s;
EJECTA.t_days         = t_days;

EJECTA.v_ion_ms       = v_ion_ms;
EJECTA.E_ion_eV       = E_ion_eV;
EJECTA.Ndot_ion_total = Ndot_ion_total;
EJECTA.Ndot_ion_hit   = Ndot_ion_hit;
EJECTA.Gamma_ion_m2s  = Gamma_ion_m2s;
EJECTA.P_beam_Pa      = P_beam_Pa;

EJECTA.mdot_low_kgps  = mdot_low_kgps;
EJECTA.mdot_nom_kgps  = mdot_nom_kgps;
EJECTA.mdot_high_kgps = mdot_high_kgps;
EJECTA.mdot_low_gday  = mdot_low_gday;
EJECTA.mdot_nom_gday  = mdot_nom_gday;
EJECTA.mdot_high_gday = mdot_high_gday;
EJECTA.M_low_kg       = M_low_kg;
EJECTA.M_nom_kg       = M_nom_kg;
EJECTA.M_high_kg      = M_high_kg;

EJECTA.dust_lift = dust_lift;

EJECTA.contam.A_sc_m2            = cfg_sput.A_sc_m2;
EJECTA.contam.rho_film_kgm3      = cfg_sput.rho_film_kgm3;
EJECTA.contam.Ndot_sc_nom        = Ndot_sc_nom;
EJECTA.contam.mdot_sc_low_kgps   = mdot_sc_low_kgps;
EJECTA.contam.mdot_sc_nom_kgps   = mdot_sc_nom_kgps;
EJECTA.contam.mdot_sc_high_kgps  = mdot_sc_high_kgps;
EJECTA.contam.M_sc_low_kg        = M_sc_low_kg;
EJECTA.contam.M_sc_nom_kg        = M_sc_nom_kg;
EJECTA.contam.M_sc_high_kg       = M_sc_high_kg;
EJECTA.contam.film_rate_nom_nm_day  = film_rate_nom_nm_day;
EJECTA.contam.film_total_low_um     = film_total_low_um;
EJECTA.contam.film_total_nom_um     = film_total_nom_um;
EJECTA.contam.film_total_high_um    = film_total_high_um;
EJECTA.contam.t_transit_nom_ms      = t_transit_nom_ms;

%% =========================================================================
%% K) CONSOLE SUMMARY
%% =========================================================================
fprintf('\n');
fprintf('=====================================================================\n');
fprintf('IBD PLUME–SURFACE INTERACTION SUMMARY\n');
fprintf('=====================================================================\n');

fprintf('\n-- Beam / material assumptions --\n');
fprintf('Ion mass:                  %.2f amu  (Xe+)\n', cfg_sput.m_ion_amu);
fprintf('Target particle mass:      %.2f amu\n', cfg_sput.m_target_amu);
fprintf('Sputter yields (L/N/H):   [%.2f, %.2f, %.2f] atoms/ion\n', ...
    cfg_sput.Y_low, cfg_sput.Y_nom, cfg_sput.Y_high);
fprintf('Sputtered energy (L/N/H): [%.1f, %.1f, %.1f] eV\n', ...
    cfg_sput.E_sput_low_eV, cfg_sput.E_sput_nom_eV, cfg_sput.E_sput_high_eV);

fprintf('\n-- Asteroid gravity --\n');
fprintf('Mass:            %.3e kg\n', m_ast_kg);
fprintf('Surface gravity: %.3e m/s^2\n', g_ast_ms2);
fprintf('Escape speed:    %.3e m/s\n', v_esc_ms);

fprintf('\n-- Sputtered-particle speeds --\n');
fprintf('Low  (%.0f eV):  %.3e m/s  (%.1fx escape)\n', ...
    cfg_sput.E_sput_low_eV,  v_sput_low_ms,  v_sput_low_ms  / v_esc_ms);
fprintf('Nom  (%.0f eV):  %.3e m/s  (%.1fx escape)\n', ...
    cfg_sput.E_sput_nom_eV,  v_sput_nom_ms,  v_sput_nom_ms  / v_esc_ms);
fprintf('High (%.0f eV): %.3e m/s  (%.1fx escape)\n', ...
    cfg_sput.E_sput_high_eV, v_sput_high_ms, v_sput_high_ms / v_esc_ms);

if v_sput_low_ms > v_esc_ms
    fprintf('All sputtered particles exceed escape speed.\n');
else
    fprintf('NOTE: low-energy sputtered particles do NOT exceed escape speed.\n');
end

fprintf('\n');
for drep = cfg_sput.d_report_m
    [~, idx] = min(abs(d_m - drep));

    fprintf('---------------------------------------------------------------------\n');
    fprintf('Stand-off:            %.1f m\n', d_m(idx));
    fprintf('Beam footprint:       %.3e m^2\n', A_beam_m2(idx));
    fprintf('Geometric coupling:   %.4f\n', eta_geom(idx));
    fprintf('Ion velocity:         %.3e m/s\n', v_ion_ms(idx));
    fprintf('Ion energy:           %.1f eV\n', E_ion_eV(idx));
    fprintf('Ion rate on surface:  %.3e s^{-1}\n', Ndot_ion_hit(idx));
    fprintf('Ion flux (surface):   %.3e ions/m^2/s\n', Gamma_ion_m2s(idx));
    fprintf('Beam pressure:        %.3e Pa\n', P_beam_Pa(idx));
    fprintf('Burn time for dv:     %.2f days\n', t_days(idx));

    fprintf('\n');
    fprintf('Low  (Y=%.2f):  rate = %.3e kg/s = %.3f g/day,  total = %.3e kg\n', ...
        cfg_sput.Y_low,  mdot_low_kgps(idx),  mdot_low_gday(idx),  M_low_kg(idx));
    fprintf('Nom  (Y=%.2f):  rate = %.3e kg/s = %.3f g/day,  total = %.3e kg\n', ...
        cfg_sput.Y_nom,  mdot_nom_kgps(idx),  mdot_nom_gday(idx),  M_nom_kg(idx));
    fprintf('High (Y=%.2f):  rate = %.3e kg/s = %.3f g/day,  total = %.3e kg\n', ...
        cfg_sput.Y_high, mdot_high_kgps(idx), mdot_high_gday(idx), M_high_kg(idx));

    fprintf('\n');
    for ci = 1:numel(Pcoh)
        fprintf('Beam pressure > %.1f Pa?  %s\n', Pcoh(ci), yn(P_beam_Pa(idx) > Pcoh(ci)));
    end

    fprintf('\n');
    fprintf('-- Spacecraft contamination at d = %.0f m --\n', d_m(idx));
    fprintf('Intercepted fraction (A_sc/pi*d^2): %.3e\n', cfg_sput.A_sc_m2 / (pi * d_m(idx)^2));
    fprintf('Transit time (nom):   %.2f ms\n', t_transit_nom_ms(idx));
    fprintf('Nom  (Y=%.2f):  mass rate on S/C = %.3e kg/s,  film rate = %.3e nm/day\n', ...
        cfg_sput.Y_nom, mdot_sc_nom_kgps(idx), film_rate_nom_nm_day(idx));
    fprintf('                cumulative mass = %.3e kg,  film = %.4f um over burn\n', ...
        M_sc_nom_kg(idx), film_total_nom_um(idx));
    fprintf('High (Y=%.2f):  mass rate on S/C = %.3e kg/s,  film rate = %.3e nm/day\n', ...
        cfg_sput.Y_high, mdot_sc_high_kgps(idx), film_rate_high_nm_day(idx));
    fprintf('                cumulative mass = %.3e kg,  film = %.4f um over burn\n', ...
        M_sc_high_kg(idx), film_total_high_um(idx));
end

fprintf('\n-- Spacecraft contamination assumptions --\n');
fprintf('Spacecraft beam-facing area:  %.2f m^2  (%.1f m x %.1f m)\n', ...
    cfg_sput.A_sc_m2, 2.3, 3.0);
fprintf('Assumed deposited film density: %.0f kg/m^3\n', cfg_sput.rho_film_kgm3);
fprintf('Angular distribution: cosine (Lambertian), S/C on-axis (worst case)\n');

fprintf('\n-- Free-flight travel distances --\n');
for k = 1:numel(cfg_sput.t_flight_s)
    fprintf('After %4.0f s:  low/nom/high = %.3e / %.3e / %.3e m\n', ...
        cfg_sput.t_flight_s(k), range_low_m(k), range_nom_m(k), range_high_m(k));
end

% ---- Instrument contamination assessment at selected stand-off ----------
[~, idx_assess] = min(abs(d_m - cfg_sput.d_assess_m));
film_nom_nm  = film_total_nom_um(idx_assess)  * 1000;   % [nm]
film_high_nm = film_total_high_um(idx_assess) * 1000;   % [nm]
film_low_nm  = film_total_low_um(idx_assess)  * 1000;   % [nm]

fprintf('\n=====================================================================\n');
fprintf('INSTRUMENT CONTAMINATION ASSESSMENT\n');
fprintf('Selected stand-off: %.0f m  (nearest sweep point: %.1f m)\n', ...
    cfg_sput.d_assess_m, d_m(idx_assess));
fprintf('Film thickness at this stand-off:\n');
fprintf('  Low  yield (Y=%.2f):  %.3f nm\n', cfg_sput.Y_low,  film_low_nm);
fprintf('  Nom  yield (Y=%.2f):  %.3f nm\n', cfg_sput.Y_nom,  film_nom_nm);
fprintf('  High yield (Y=%.2f):  %.3f nm\n', cfg_sput.Y_high, film_high_nm);
fprintf('(Film density assumed: %.0f kg/m^3;  A_sc = %.1f m^2)\n', ...
    cfg_sput.rho_film_kgm3, cfg_sput.A_sc_m2);
fprintf('---------------------------------------------------------------------\n');
fprintf('%-30s  %-10s  %-10s  %s\n', 'Instrument', 'Nom [nm]', 'High [nm]', 'Assessment');
fprintf('%-30s  %-10s  %-10s  %s\n', '----------', '--------', '---------', '----------');

fprintf('%-30s  %-10.3f  %-10.3f  %s\n', 'Wide Angle Camera (VIS)', ...
    film_nom_nm, film_high_nm, risk_str(film_high_nm, 100, 300));
fprintf('%-30s  %-10.3f  %-10.3f  %s\n', 'Framing Camera (VIS)', ...
    film_nom_nm, film_high_nm, risk_str(film_high_nm, 100, 300));
fprintf('%-30s  %-10.3f  %-10.3f  %s\n', 'Scanning LIDAR (NIR)', ...
    film_nom_nm, film_high_nm, ...
    sprintf('Loss ~ (t/lam)^2 ~ %.2e at 1064 nm  ->  %s', ...
    (film_high_nm/1064)^2, risk_str(film_high_nm, 50, 200)));
fprintf('%-30s  %-10s  %-10s  %s\n', 'Gravity Gradiometer', ...
    'N/A', 'N/A', 'Non-optical — mass deposition negligible  ->  NEGLIGIBLE');
fprintf('%-30s  %-10.3f  %-10.3f  %s\n', 'Thermal IR (OTES-type)', ...
    film_nom_nm, film_high_nm, ...
    sprintf('Threshold > 1e7 nm (10 um) [2,5]  ->  %s', ...
    risk_str(film_high_nm, 1e4, 1e7)));
fprintf('%-30s  %-10.3f  %-10.3f  %s\n', 'XRF / Soft X-ray (REXIS-type)', ...
    film_nom_nm, film_high_nm, ...
    sprintf('Threshold ~10 nm [3,4]  ->  %s', ...
    risk_str(film_high_nm, 5, 10)));
fprintf('%-30s  %-10s  %-10s  %s\n', 'Gamma-ray spectrometer', ...
    'N/A', 'N/A', 'keV–MeV photons penetrate nm films  ->  NEGLIGIBLE');
fprintf('%-30s  %-10.4f  %-10.4f  %s\n', 'Solar panels (lateral)', ...
    film_nom_nm * 0.03, film_high_nm * 0.03, ...
    sprintf('Edge-on factor ~0.03; effective = %.3f nm  ->  %s', ...
    film_high_nm * 0.03, risk_str(film_high_nm * 0.03, 100, 1000)));

fprintf('---------------------------------------------------------------------\n');
fprintf('Notes:\n');
fprintf('  Risk labels: LOW RISK < 10%% of threshold; MONITOR 10-100%%;\n');
fprintf('               CAUTION within threshold band; EXCEEDS above upper bound.\n');
fprintf('  VIS thresholds from NASA-CR-4740 and UV photopolymerisation studies [1,6].\n');
fprintf('  OTES threshold from Christensen et al. (2018) [2].\n');
fprintf('  REXIS soft X-ray CCD threshold ~10 nm molecular film [3,4].\n');
fprintf('  Solar panel edge-on geometric factor: cos^2(80 deg) ~ 0.03.\n');
fprintf('  To change assessment stand-off, set cfg_sput.d_assess_m in section A.\n');
fprintf('=====================================================================\n\n');

%% =========================================================================
%% L) DIAGNOSTIC FIGURES
%% =========================================================================
lw_main = 2.0;
lw_ref  = 1.0;

% Global font sizes (edit here once for all plots)
fs_axes   = 12;   % axis tick labels
fs_labels = 12;   % x/y axis labels
fs_title  = 11;   % sgtitle
fs_legend = 12;   % legends
fs_text   = 11;    % spare text / annotations if added later

%% ---- S1: Beam pressure vs stand-off -----------------------------------
figure; hold on; grid on;

plot(d_m, P_beam_Pa, 'k-', 'LineWidth', lw_main, 'DisplayName', 'Beam pressure');

coh_grey = [0.35 0.55 0.75];
for ci = 1:numel(Pcoh)
    yline(Pcoh(ci), '--', 'LineWidth', lw_ref, 'Color', coh_grey(ci)*[1 1 1], ...
        'DisplayName', sprintf('%.1f Pa cohesion', Pcoh(ci)));
end

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Average beam pressure [Pa]', 'FontSize', fs_labels);
set(gca, 'YScale', 'log', 'FontSize', fs_axes);
lgd = legend('Location', 'northeast');
set(lgd, 'FontSize', fs_legend);
hold off;

%% ---- S2: Ion flux vs stand-off ----------------------------------------
figure; hold on; grid on;

plot(d_m, Gamma_ion_m2s, 'k-', 'LineWidth', lw_main);

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Local ion flux [ions m^{-2} s^{-1}]', 'FontSize', fs_labels);
set(gca, 'YScale', 'log', 'FontSize', fs_axes);
sgtitle('Ion Flux at Asteroid Surface vs Stand-off Distance', ...
    'FontSize', fs_title, 'FontWeight', 'bold');
hold off;

%% ---- S3: Sputtered mass rate envelope vs stand-off --------------------
figure; hold on; grid on;

xfill = d_m(:);

hBand = fill([xfill; flipud(xfill)], [mdot_low_gday(:); flipud(mdot_high_gday(:))], ...
    [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.25, ...
    'DisplayName', sprintf('Yield range: %.2f–%.2f atoms/ion', cfg_sput.Y_low, cfg_sput.Y_high));

plot(d_m, mdot_low_gday,  '--', 'LineWidth', 1.2, 'Color', [0.55 0.55 0.55], 'HandleVisibility', 'off');
plot(d_m, mdot_high_gday, '--', 'LineWidth', 1.2, 'Color', [0.55 0.55 0.55], 'HandleVisibility', 'off');

hNom = plot(d_m, mdot_nom_gday, 'k-', 'LineWidth', lw_main, ...
    'DisplayName', sprintf('Nominal yield (Y = %.2f)', cfg_sput.Y_nom));

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Sputtered mass rate [g/day]', 'FontSize', fs_labels);
set(gca, 'YScale', 'log', 'FontSize', fs_axes);
sgtitle('Sputtered Mass Rate vs Stand-off Distance', 'FontSize', fs_title, 'FontWeight', 'bold');
lgd = legend([hBand hNom], 'Location', 'northeast');
set(lgd, 'FontSize', fs_legend);
hold off;

%% ---- S4: Burn duration vs stand-off -----------------------------------
figure; hold on; grid on;

plot(d_m, t_days, 'k-', 'LineWidth', lw_main);

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Burn time to achieve target \Deltav [days]', 'FontSize', fs_labels);
set(gca, 'FontSize', fs_axes);
sgtitle('IBD Burn Duration vs Stand-off Distance', 'FontSize', fs_title, 'FontWeight', 'bold');
hold off;

%% ---- S5: Cumulative sputtered mass vs stand-off -----------------------
figure; hold on; grid on;

hBand = fill([xfill; flipud(xfill)], [M_low_kg(:); flipud(M_high_kg(:))], ...
    [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.25, ...
    'DisplayName', sprintf('Yield range: %.2f–%.2f atoms/ion', cfg_sput.Y_low, cfg_sput.Y_high));

plot(d_m, M_low_kg,  '--', 'LineWidth', 1.2, 'Color', [0.55 0.55 0.55], 'HandleVisibility', 'off');
plot(d_m, M_high_kg, '--', 'LineWidth', 1.2, 'Color', [0.55 0.55 0.55], 'HandleVisibility', 'off');

hNom = plot(d_m, M_nom_kg, 'k-', 'LineWidth', lw_main, ...
    'DisplayName', sprintf('Nominal yield (Y = %.2f)', cfg_sput.Y_nom));

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Total sputtered mass over burn [kg]', 'FontSize', fs_labels);
set(gca, 'YScale', 'log', 'FontSize', fs_axes);
sgtitle('Cumulative Sputtered Mass over Required Burn', 'FontSize', fs_title, 'FontWeight', 'bold');
lgd = legend([hBand hNom], 'Location', 'northeast');
set(lgd, 'FontSize', fs_legend);
hold off;

%% ---- S6: Sputtered-particle speed vs escape speed ---------------------
figure; hold on; grid on;

v_cases = [v_sput_low_ms, v_sput_nom_ms, v_sput_high_ms];
bar(1:3, v_cases, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'k', 'LineWidth', 1.0);
plot([0.5 3.5], [v_esc_ms v_esc_ms], 'k--', 'LineWidth', 1.5, 'DisplayName', 'Escape speed');

set(gca, 'XTick', 1:3);
set(gca, 'XTickLabel', {'Low E_{sput}', 'Nom E_{sput}', 'High E_{sput}'});
set(gca, 'FontSize', fs_axes);
ylabel('Characteristic speed [m/s]', 'FontSize', fs_labels);
sgtitle('Sputtered-Particle Speed vs Asteroid Escape Speed', ...
    'FontSize', fs_title, 'FontWeight', 'bold');
lgd = legend('Escape speed', 'Location', 'northwest');
set(lgd, 'FontSize', fs_legend);
hold off;

%% ---- S7: Spacecraft mass deposition rate vs stand-off -----------------
figure; hold on; grid on;

ng_per_kg = 1e12;

xfill_c = d_m(:);
hBand = fill([xfill_c; flipud(xfill_c)], ...
    [mdot_sc_low_kgps(:)*ng_per_kg; flipud(mdot_sc_high_kgps(:)*ng_per_kg)], ...
    [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.25, ...
    'DisplayName', sprintf('Yield range: %.2f–%.2f atoms/ion', cfg_sput.Y_low, cfg_sput.Y_high));
plot(d_m, mdot_sc_low_kgps*ng_per_kg,  '--', 'LineWidth', 1.2, 'Color', [0.55 0.55 0.55], 'HandleVisibility', 'off');
plot(d_m, mdot_sc_high_kgps*ng_per_kg, '--', 'LineWidth', 1.2, 'Color', [0.55 0.55 0.55], 'HandleVisibility', 'off');
hNom = plot(d_m, mdot_sc_nom_kgps*ng_per_kg, 'k-', 'LineWidth', lw_main, ...
    'DisplayName', sprintf('Nominal yield (Y = %.2f)', cfg_sput.Y_nom));

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Mass deposition rate on spacecraft [ng/s]', 'FontSize', fs_labels);
set(gca, 'YScale', 'log', 'FontSize', fs_axes);
sgtitle({ ...
    'Sputtered Mass Deposition Rate on Spacecraft vs Stand-off', ...
    sprintf('(A_{sc} = %.1f m^2, cosine distribution, on-axis)', cfg_sput.A_sc_m2)}, ...
    'FontSize', fs_title, 'FontWeight', 'bold');
lgd = legend([hBand hNom], 'Location', 'northeast');
set(lgd, 'FontSize', fs_legend);
hold off;

%% ---- S8: Cumulative film thickness vs stand-off -----------------------
figure; hold on; grid on;

nm_per_um = 1e3;

hBand = fill([xfill_c; flipud(xfill_c)], ...
    [film_total_low_um(:)*nm_per_um; flipud(film_total_high_um(:)*nm_per_um)], ...
    [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.25, ...
    'DisplayName', sprintf('Yield range: %.2f–%.2f atoms/ion', cfg_sput.Y_low, cfg_sput.Y_high));
plot(d_m, film_total_low_um*nm_per_um,  '--', 'LineWidth', 1.2, 'Color', [0.55 0.55 0.55], 'HandleVisibility', 'off');
plot(d_m, film_total_high_um*nm_per_um, '--', 'LineWidth', 1.2, 'Color', [0.55 0.55 0.55], 'HandleVisibility', 'off');
hNom = plot(d_m, film_total_nom_um*nm_per_um, 'k-', 'LineWidth', lw_main, ...
    'DisplayName', sprintf('Nominal yield (Y = %.2f)', cfg_sput.Y_nom));

% Add vertical marker at the assessment stand-off
%xline(d_m(idx_assess), 'b--', 'LineWidth', 1.0, ...
    %'DisplayName', sprintf('Assessment d = %.0f m', d_m(idx_assess)));

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Cumulative deposited film thickness [nm]', 'FontSize', fs_labels);
set(gca, 'YScale', 'log', 'FontSize', fs_axes);
sgtitle('Cumulative Deposited Film Thickness vs Stand-off Distance', ...
    'FontSize', fs_title, 'FontWeight', 'bold');
lgd = legend([hBand hNom], 'Location', 'northeast');
set(lgd, 'FontSize', fs_legend);
hold off;

%% =========================================================================
%% LOCAL HELPERS
%% =========================================================================
function s = yn(x)
if x, s = 'YES'; else, s = 'NO'; end
end

function s = risk_str(val_nm, warn_nm, high_nm)
% Returns a risk label based on film thickness vs instrument thresholds.
%   val_nm   : film thickness to assess [nm]
%   warn_nm  : lower threshold — MONITOR above this [nm]
%   high_nm  : upper threshold — EXCEEDS above this [nm]
if val_nm < 0.1 * warn_nm
    s = sprintf('LOW RISK    (%.3f nm  <  10%% of %.0f nm threshold)', val_nm, warn_nm);
elseif val_nm < warn_nm
    s = sprintf('MONITOR     (%.3f nm  =  %.0f%% of %.0f nm threshold)', ...
        val_nm, 100*val_nm/warn_nm, warn_nm);
elseif val_nm < high_nm
    s = sprintf('CAUTION     (%.3f nm  within threshold band %.0f–%.0f nm)', ...
        val_nm, warn_nm, high_nm);
else
    s = sprintf('** EXCEEDS  (%.3f nm  >  %.0f nm upper threshold) **', val_nm, high_nm);
end
end