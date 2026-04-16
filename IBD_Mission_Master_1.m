%% =========================================================================
%% IBD_Mission_Master_1_FINAL.m
%% =========================================================================
% IBD Mission Core — canonical geometry, coupling, and baseline performance
%
% Purpose
%   Define the IBD beam geometry and geometric coupling efficiency as a
%   function of stand-off distance, and compute baseline effective thrust
%   and time-to-delta-v arrays for the nominal mission configuration.
%
% Assumptions
%   - Conical beam with uniform intensity across the half-angle.
%   - Asteroid surface treated as a flat disc perpendicular to the beam
%     axis (valid when stand-off >> asteroid radius).
%   - Baseline arrays (T_eff, t_days) use geometric coupling ONLY.
%     Surface momentum transfer and incidence-angle factors are stored
%     in cfg and applied downstream where appropriate (e.g. summary,
%     plume-surface, deflection scripts).
%
% Outputs
%   IBD.cfg       : scalar configuration struct (all inputs)
%   IBD.mission.* : canonical vectors over the stand-off grid
%
%   Legacy flat variables are also exported for backward compatibility
%   with older plotting and analysis scripts.
%
% Recommended run order
%   1) IBD_Mission_Master_1.m          <-- this script
%   2) IBD_Thruster_Performance_2.m
%   3) IBD_Plots_3.m / IBD_Summary_Report_4.m / etc.
% =========================================================================

clc;

%% -------------------- A) User inputs --------------------
cfg = struct();

% Beam geometry
cfg.theta_deg    = 15;          % beam half-angle [deg]

% Beam thrust (per thruster)
cfg.T_beam_mN    = 85;          % commanded thrust per beam thruster [mN]
cfg.N_beam       = 2;           % number of beam thrusters

% Asteroid physical parameters
cfg.R_ast_m      = 30;          % radius [m]
cfg.rho_kgm3     = 3500;        % bulk density [kg/m^3]

% Mission targets
cfg.dv_target_ms = 3e-3;        % target delta-v [m/s]
cfg.dur_post_yrs = 5;           % post-burn ballistic drift duration [years]

% Coupling modifiers (stored here; applied in downstream scripts)
cfg.surface      = 1.0;         % surface momentum-transfer efficiency [0..1]
cfg.incident_deg = 0;           % beam incidence angle [deg] (0 = normal)

% Stand-off grid
cfg.d_max_m = 1000;             % maximum stand-off distance [m]
cfg.N_d     = 1001;             % grid points (1001 => 1 m resolution)

%% -------------------- B) Input validation --------------------
assert(cfg.R_ast_m > 0,      'Asteroid radius must be positive.');
assert(cfg.rho_kgm3 > 0,     'Asteroid density must be positive.');
assert(cfg.T_beam_mN > 0,    'Beam thrust must be positive.');
assert(cfg.theta_deg > 0 && cfg.theta_deg < 90, ...
    'Beam half-angle must be in (0, 90) degrees.');

%% -------------------- C) Stand-off grid --------------------
d      = linspace(0, cfg.d_max_m, cfg.N_d).';   % column [m]
d_safe = max(d, 1e-6);                           % guard against d = 0

%% -------------------- D) Beam footprint and geometric coupling --------------------
theta_rad = deg2rad(cfg.theta_deg);

r_beam = d_safe .* tan(theta_rad);               % beam radius at asteroid [m]
A_beam = pi .* r_beam.^2;                        % beam cross-sectional area [m^2]
A_ast  = pi .* cfg.R_ast_m.^2;                   % asteroid projected area [m^2]

eta_geom = min(1, A_ast ./ A_beam);              % geometric interception fraction
eta_geom(d == 0) = 1;                            % exact at zero stand-off

% Total coupling including surface and incidence factors (precomputed for
% downstream convenience — NOT used in the baseline arrays below).
eta_total = eta_geom .* cfg.surface .* cosd(cfg.incident_deg);
eta_total = max(min(eta_total, 1), 0);

%% -------------------- E) Baseline effective thrust and time-to-dv --------------------
% These use geometric coupling only, consistent with the IBD geometry
% trade space.  Full coupling is applied in the summary/deflection scripts.

T_total_N    = (cfg.T_beam_mN * 1e-3) * cfg.N_beam;      % total produced thrust [N]
T_eff_geom_N = max(T_total_N .* eta_geom, 1e-12);         % effective thrust (geom) [N]

m_ast = cfg.rho_kgm3 * (4/3) * pi * cfg.R_ast_m^3;       % asteroid mass [kg]

t_req_s_geom = (cfg.dv_target_ms * m_ast) ./ T_eff_geom_N;  % required burn time [s]
t_days_geom  = t_req_s_geom / 86400;                        % [days]

%% -------------------- F) Structured output --------------------
IBD = struct();
IBD.cfg = cfg;

IBD.mission.d            = d;
IBD.mission.r_beam       = r_beam;
IBD.mission.A_beam       = A_beam;
IBD.mission.A_ast        = A_ast;
IBD.mission.eta_geom     = eta_geom;
IBD.mission.eta_total    = eta_total;

IBD.mission.m_ast        = m_ast;
IBD.mission.T_total_N    = T_total_N;
IBD.mission.T_eff_geom_N = T_eff_geom_N;
IBD.mission.t_days_geom  = t_days_geom;

%% -------------------- G) Legacy flat exports --------------------
% Row vectors to match the conventions of the original plotting scripts.

theta_deg    = cfg.theta_deg;
T0_mN        = cfg.T_beam_mN;
T0_num       = cfg.N_beam;
R_ast        = cfg.R_ast_m;
rho          = cfg.rho_kgm3;
dv_target    = cfg.dv_target_ms;
dur_target   = cfg.dur_post_yrs;
surface      = cfg.surface;
incident_deg = cfg.incident_deg;

d      = d(:).';
r_beam = r_beam(:).';
A_beam = A_beam(:).';
eta_c  = eta_geom(:).';       % "eta_c" = geometric coupling (legacy name)
T_eff  = T_eff_geom_N(:).';   % effective thrust vs d (geom only) [N]
t_days = t_days_geom(:).';    % time-to-dv vs d (geom only) [days]