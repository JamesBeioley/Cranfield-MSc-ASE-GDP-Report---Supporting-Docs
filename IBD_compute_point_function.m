function pt = IBD_compute_point_function(cfg, db, d_query_m)
% IBD_compute_point_function  Evaluate a single IBD design point at a given stand-off.
%
%   pt = ibd_compute_point(cfg, db, d_query_m)
%
%   Computes beam geometry, coupling, effective thrust, time-to-delta-v,
%   power budget, propellant mass, and thruster lifetime fraction for a
%   single stand-off distance.  All quantities are returned in a scalar
%   struct suitable for console reporting or sweep tables.
%
%   Inputs
%     cfg        — configuration struct (from IBD_Summary_Report_4 or similar)
%     db         — thruster database struct (isp, life_hr, TP_mN_per_W, etc.)
%     d_query_m  — stand-off distance to evaluate [m]
%
%   Output
%     pt         — struct containing all derived quantities at d_query_m

g0 = 9.81;

%% --- Beam geometry and coupling at the queried stand-off ----------------
theta = deg2rad(cfg.theta_deg);

d_used = d_query_m;
rbeam  = max(d_used, 1e-6) * tan(theta);        % beam radius at asteroid [m]
Abeam  = pi * rbeam^2;                           % beam cross-section [m^2]
Aast   = pi * cfg.R_ast_m^2;                     % asteroid projected area [m^2]

eta_geom  = min(1, Aast / Abeam);                % geometric interception
eta_total = eta_geom * cfg.surface * cosd(cfg.incident_deg);
eta_total = max(min(eta_total, 1), 0);

%% --- Asteroid mass ------------------------------------------------------
m_ast = cfg.rho_kgm3 * (4/3) * pi * cfg.R_ast_m^3;

%% --- Beam thruster properties -------------------------------------------
thr_key  = strrep(cfg.thruster_name, '-', '_');
Isp_s    = db.isp.(thr_key);
life_hr  = db.life_hr.(thr_key);
TP_mN_W  = db.TP_mN_per_W.(thr_key);

% Infer power from thrust-power slope if not specified explicitly
if isnan(cfg.P_cmd_W)
    P_cmd_W = cfg.T_cmd_mN / max(TP_mN_W, 1e-12);
else
    P_cmd_W = cfg.P_cmd_W;
end

%% --- Effective thrust and required burn time ----------------------------
T_total_N = (cfg.T_cmd_mN * 1e-3) * cfg.N_beam;    % total produced thrust [N]
T_eff_N   = max(T_total_N * eta_total, 1e-12);      % effective on asteroid [N]

t_req_s = (cfg.dv_target_ms * m_ast) / T_eff_N;     % burn time [s]
t_days  = t_req_s / 86400;
t_yrs   = t_req_s / (365.25 * 86400);

%% --- Beam propellant and lifetime ---------------------------------------
mdot_beam_kgps = T_total_N / (g0 * Isp_s);
mprop_beam_kg  = mdot_beam_kgps * t_req_s;

op_hours       = t_req_s / 3600;
life_frac_beam = 100 * (op_hours / max(life_hr, 1e-12));

%% --- Counter-thrust (optional) ------------------------------------------
mprop_counter_kg  = 0;
mdot_counter_kgps = 0;
P_counter_cmd_W   = 0;
life_ok_counter   = true;
life_c            = NaN;
life_frac_counter = 0;

if cfg.N_counter > 0
    ckey  = strrep(cfg.counter_thruster_name, '-', '_');
    Isp_c = db.isp.(ckey);
    life_c = db.life_hr.(ckey);
    TP_c  = db.TP_mN_per_W.(ckey);

    T_counter_total_N    = cfg.counter_factor * T_total_N;
    T_counter_per_thr_mN = (1e3 * T_counter_total_N) / max(cfg.N_counter, 1);
    P_counter_cmd_W      = T_counter_per_thr_mN / max(TP_c, 1e-12);

    mdot_counter_kgps = T_counter_total_N / (g0 * Isp_c);
    mprop_counter_kg  = mdot_counter_kgps * t_req_s;

    life_ok_counter   = (op_hours <= life_c);
    life_frac_counter = 100 * (op_hours / max(life_c, 1e-12));
end

%% --- Power totals -------------------------------------------------------
P_beam_total_kW    = (cfg.N_beam    * P_cmd_W)        / 1000;
P_counter_total_kW = (cfg.N_counter * P_counter_cmd_W) / 1000;
P_total_kW         = P_beam_total_kW + P_counter_total_kW;

%% --- Propellant total ---------------------------------------------------
mprop_total_kg = mprop_beam_kg + mprop_counter_kg;

%% --- Power-envelope check (if data available) ---------------------------
Pmin = NaN;  Pmax = NaN;  power_ok = true;
if ~isempty(db.P_env) && ~isempty(db.names)
    k = find(strcmpi(db.names, cfg.thruster_name), 1);
    if ~isempty(k)
        Pmin     = db.P_env(k, 1);
        Pmax     = db.P_env(k, 2);
        power_ok = (P_cmd_W >= Pmin) && (P_cmd_W <= Pmax);
    end
end

%% --- Pack output struct -------------------------------------------------
pt.d_used_m           = d_used;
pt.r_beam_m           = rbeam;
pt.A_beam_m2          = Abeam;
pt.A_ast_m2           = Aast;
pt.eta_geom           = eta_geom;
pt.eta_total          = eta_total;

pt.m_ast_kg           = m_ast;
pt.T_total_N          = T_total_N;
pt.T_eff_N            = T_eff_N;

pt.t_req_s            = t_req_s;
pt.t_days             = t_days;
pt.t_yrs              = t_yrs;

pt.P_cmd_W            = P_cmd_W;
pt.P_beam_total_kW    = P_beam_total_kW;
pt.P_counter_cmd_W    = P_counter_cmd_W;
pt.P_counter_total_kW = P_counter_total_kW;
pt.P_total_kW         = P_total_kW;

pt.mdot_beam_kgps     = mdot_beam_kgps;
pt.mprop_beam_kg      = mprop_beam_kg;
pt.mdot_counter_kgps  = mdot_counter_kgps;
pt.mprop_counter_kg   = mprop_counter_kg;
pt.mprop_total_kg     = mprop_total_kg;

pt.op_hours           = op_hours;
pt.life_hr_beam       = life_hr;
pt.life_frac_beam     = life_frac_beam;
pt.life_hr_counter    = life_c;
pt.life_frac_counter  = life_frac_counter;

pt.life_ok_beam       = (op_hours <= life_hr);
pt.life_ok_counter    = life_ok_counter;

pt.Pmin_W             = Pmin;
pt.Pmax_W             = Pmax;
pt.power_ok           = power_ok;

end