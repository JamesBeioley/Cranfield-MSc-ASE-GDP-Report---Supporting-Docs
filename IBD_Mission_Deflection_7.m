%% =========================================================================
%% IBD_Mission_Deflection_7.m
%% =========================================================================
% Along-Track Deflection Analysis for Ion Beam Deflection
%
% Purpose
%   Implement the deflection chain that converts a tangential Δv on a
%   heliocentric orbit into an along-track displacement at a future
%   encounter, and produce the reference-point summary and parametric
%   figures used in §6.2.2 and §6.5.3 of the Payload Work Package report.
%
%       effective thrust --> asteroid acceleration --> delivered Δv
%         --> semi-major axis change (vis-viva, tangential impulse)
%         --> orbital period change (Kepler's third law)
%         --> along-track phase drift at encounter
%
% Physics note
%   A tangential Δv on a near-circular orbit produces, to first order:
%       Δa    = 2 a Δv / v
%       ΔT    = 3 T Δv / v
%       Δx(Δt) = 3 Δv Δt       (phase drift, asymptotic form)
%
%   The along-track drift is NOT a free-space kinematic coast: the
%   asteroid does not translate in a straight line at the delivered Δv.
%   Instead, each orbit after the impulse it arrives ΔT later than its
%   unperturbed trajectory, and the accumulated lag (Δt/T)·ΔT, converted
%   to distance via multiplication by v, gives Δx = 3·Δv·Δt.
%
% Assumptions
%   - Thrust is applied along the heliocentric velocity vector
%     (prograde push; increases a and T, so the asteroid arrives later).
%   - Heliocentric orbit is approximated as circular at a = 1.07 AU.
%   - Burn is treated as effectively instantaneous at its midpoint; the
%     error relative to the finite-duration case is t_push/(2·t_drift),
%     i.e. ~0.8% for the ESCUT 80-day burn / 5-year drift baseline.
%   - Post-burn drift time t_drift is the elapsed time from end-of-burn
%     to encounter, matching the definition of Δt in Eq. (6-5) of the
%     report and the "5 years post-IBD" phrasing in §6.2.2.
%
% Recommended run order
%   1) IBD_Mission_Master_1.m
%   2) IBD_Mission_Deflection_7.m       <-- this script
%
% Output
%   - Console summary at the reference operating point (d = 100 m,
%     t_push = 80 d, t_drift = 5 yr) with pass/fail against the PL-IBD
%     requirement floor and against the §6.2.2 hand-calculated values.
%   - Six parametric figures (see sections F–K below).
% =========================================================================

clc;

%% -------------------- A) Load canonical inputs --------------------
% Inherit from the IBD struct populated by IBD_Mission_Master_1.m, with
% a fallback to flat legacy variables for standalone use.
if exist('IBD','var') && isfield(IBD,'cfg') && isfield(IBD,'mission')
    theta_deg    = IBD.cfg.theta_deg;
    T0_mN        = IBD.cfg.T_beam_mN;
    T0_num       = IBD.cfg.N_beam;
    R_ast        = IBD.cfg.R_ast_m;
    rho          = IBD.cfg.rho_kgm3;
    dv_target    = IBD.cfg.dv_target_ms;
    dur_target   = IBD.cfg.dur_post_yrs;
    surface      = IBD.cfg.surface;
    incident_deg = IBD.cfg.incident_deg;
else
    need = {'theta_deg','T0_mN','T0_num','R_ast','rho', ...
            'dv_target','dur_target','surface','incident_deg'};
    for i = 1:numel(need)
        if ~exist(need{i},'var')
            error('IBD_Deflection:MissingVar', ...
                'Variable "%s" not found. Run IBD_Mission_Master_1 first.', need{i});
        end
    end
end

%% -------------------- B) Constants and reference orbit --------------------
% Circular heliocentric reference orbit for 2017 SV19 (a ≈ 1.07 AU).
mu_sun     = 1.3271244e20;                           % [m^3/s^2]
a_helio_m  = 1.495978707e11 * 1.07;                  % semi-major axis [m]
v_helio_ms = sqrt(mu_sun / a_helio_m);               % orbital velocity [m/s]
T_helio_s  = 2 * pi * sqrt(a_helio_m^3 / mu_sun);    % orbital period [s]

orb = struct( ...
    'mu_sun',     mu_sun, ...
    'a_helio_m',  a_helio_m, ...
    'v_helio_ms', v_helio_ms, ...
    'T_helio_s',  T_helio_s);

%% -------------------- C) Mission parameters --------------------
T_total_N = (T0_mN * 1e-3) * T0_num;       % total produced thrust [N]

mis = struct( ...
    'theta_deg',    theta_deg, ...
    'T_total_N',    T_total_N, ...
    'R_ast',        R_ast, ...
    'rho',          rho, ...
    'surface',      surface, ...
    'incident_deg', incident_deg);

%% -------------------- D) Plot and reporting settings --------------------
cfg = struct();

% Reference case for the console summary (matches §6.2.2 of the report).
cfg.d_ref_m       = 100;          % reference stand-off [m]
cfg.t_push_days   = 80;           % reference active IBD duration [days]
cfg.t_drift_years = dur_target;   % post-burn drift time [years]

% Preferred operating stand-off band (Figure annotation).
cfg.d_band_m = [100 200];

% Figure 1: deflection vs IBD operating time (fixed encounter time).
cfg.t_enc_years   = cfg.t_push_days/365.25 + cfg.t_drift_years;
cfg.d_plot_list_m = [100 200 300 500 1000];
cfg.t_push_days_vec = linspace(1, 365, 250);

% Figure 2: deflection vs stand-off distance.
cfg.d_vec_m          = linspace(0, 1000, 400);
cfg.t_push_list_days = [30 60 90 180 365];

% Figure 5: required Δv vs warning time.
cfg.x_target_km_list = [100 200 500 1000];
cfg.t_warn_vec_years = linspace(0.5, 20, 400);

% Figure 6: required IBD operating time vs warning time.
cfg.x_target_ref_km      = 500;
cfg.x_target_km_list_ops = [100 200 500];

%% -------------------- E) Reference-point console summary --------------------
% Evaluate at the nominal operating point and print a pass/fail summary.
pt = deflection_point(cfg.d_ref_m, cfg.t_push_days, cfg.t_drift_years, mis, orb);

% Required Δv to hit the 500 km floor over the nominal 5-year drift,
% using the phase-drift relation Δx = 3·Δv·Δt.
x_target_ref_m = cfg.x_target_ref_km * 1000;
t_drift_ref_s  = cfg.t_drift_years * 365.25 * 86400;
dv_req_ref_ms  = x_target_ref_m / (3 * t_drift_ref_s);

% Required IBD push duration to hit the 500 km floor at the reference
% stand-off, holding t_drift fixed at the nominal 5 years.
if pt.a_ast_ms2 > 0
    t_push_req_s    = dv_req_ref_ms / pt.a_ast_ms2;
    t_push_req_days = t_push_req_s / 86400;
else
    t_push_req_days = NaN;
end

% Analytical reference values for self-check.
% These are the exact physics values at the reference point
% (D = 60 m, ρ = 3500 kg/m³, T = 170 mN, t_push = 80 d, t_drift = 5 yr,
%  a_helio = 1.07 AU). §6.2.2 of the report rounds these to the headline
% figures of 3 mm/s, 33 km, 10.8 s, and ~1400 km.
dv_hand_mms      = 2.97;     % [mm/s]
dA_hand_km       = 33.00;    % [km]
dT_hand_s        = 10.81;    % [s]
x_def_hand_km    = 1406;     % [km] at Δt = 5 yr

fprintf('\n');
fprintf('=====================================================================\n');
fprintf('IBD DEFLECTION ANALYSIS SUMMARY\n');
fprintf('=====================================================================\n');

fprintf('\n-- Asteroid --\n');
fprintf('  Radius       : %6.2f m  (D = %.2f m)\n', R_ast, 2*R_ast);
fprintf('  Density      : %6.0f kg/m^3\n', rho);
fprintf('  Mass         : %10.3e kg\n', pt.m_ast_kg);

fprintf('\n-- IBD configuration --\n');
fprintf('  Beam half-angle     : %5.2f deg\n', theta_deg);
fprintf('  Beam thrusters      : %d x %.2f mN  (total %.3f N)\n', ...
    T0_num, T0_mN, T_total_N);
fprintf('  Reference stand-off : %5.0f m\n', cfg.d_ref_m);
fprintf('  Geometric coupling  : %6.4f\n', pt.eta_geom);
fprintf('  Total coupling      : %6.4f\n', pt.eta_total);
fprintf('  Effective thrust    : %10.3e N\n', pt.T_eff_N);

fprintf('\n-- Heliocentric reference orbit --\n');
fprintf('  Semi-major axis     : %6.3f AU\n', a_helio_m / 1.495978707e11);
fprintf('  Orbital velocity    : %6.2f km/s\n', v_helio_ms / 1000);
fprintf('  Orbital period      : %6.3f yr\n', T_helio_s / (365.25*86400));

fprintf('\n-- Timeline --\n');
fprintf('  Active IBD duration : %5.0f days\n', cfg.t_push_days);
fprintf('  Post-burn drift     : %5.1f years\n', cfg.t_drift_years);

fprintf('\n-- Deflection chain (MATLAB) --\n');
fprintf('  Acceleration        : %10.3e m/s^2\n', pt.a_ast_ms2);
fprintf('  Delta-v delivered   : %10.3e m/s  (%.3f mm/s)\n', ...
    pt.dv_ms, 1e3*pt.dv_ms);
fprintf('  Semi-major axis dA  : %6.2f km\n', pt.delta_a_m / 1000);
fprintf('  Period change dT    : %6.2f s\n', pt.delta_T_s);
fprintf('  Along-track dX      : %6.1f km\n', pt.x_def_km);

fprintf('\n-- Self-check vs §6.2.2 hand-calculated values --\n');
passfail('Delta-v     ', 1e3*pt.dv_ms, dv_hand_mms,    0.02);
passfail('dA          ', pt.delta_a_m/1000, dA_hand_km, 0.02);
passfail('dT          ', pt.delta_T_s,      dT_hand_s,  0.02);
passfail('dX (5 yr)   ', pt.x_def_km, x_def_hand_km,   0.02);

fprintf('\n-- Requirement check (PL-IBD-010 / PL-IBD-011) --\n');
fprintf('  Target floor        : %5.0f km (PL-IBD-011)\n', cfg.x_target_ref_km);
fprintf('  Required Δv         : %6.3f mm/s  (PL-IBD-010 floor 1.000 mm/s)\n', ...
    1e3*dv_req_ref_ms);
fprintf('  Required IBD time   : %6.2f days at d_ref\n', t_push_req_days);
fprintf('  Achieved / target   : %6.2f x\n', pt.x_def_km / cfg.x_target_ref_km);

fprintf('\nNote: a prograde push increases heliocentric a and T, so the\n');
fprintf('asteroid arrives progressively later at downstream encounter\n');
fprintf('points; along-track lag grows linearly with elapsed time.\n');
fprintf('=====================================================================\n\n');

%% -------------------- F) Figure 1 — Deflection vs IBD operating time --------------------
% For each stand-off, sweep the active IBD duration and compute the
% resulting along-track deflection. Encounter time is held fixed at
% t_enc = t_push_nominal + t_drift_nominal, so t_drift = t_enc − t_push
% shrinks as t_push grows: longer burn, shorter coast. This exposes the
% optimum operating point.

figure; hold on; grid on;

Cdef = lines(numel(cfg.d_plot_list_m));
t_enc_s = cfg.t_enc_years * 365.25 * 86400;

for i = 1:numel(cfg.d_plot_list_m)
    d_now = cfg.d_plot_list_m(i);
    x_km  = zeros(size(cfg.t_push_days_vec));

    for j = 1:numel(cfg.t_push_days_vec)
        t_push_j  = cfg.t_push_days_vec(j);
        t_push_s  = t_push_j * 86400;
        t_drift_j = max(0, (t_enc_s - t_push_s) / (365.25*86400));
        ptmp = deflection_point(d_now, t_push_j, t_drift_j, mis, orb);
        x_km(j) = ptmp.x_def_km;
    end

    plot(cfg.t_push_days_vec, x_km, 'LineWidth', 2.0, 'Color', Cdef(i,:), ...
        'DisplayName', sprintf('d = %d m', d_now));
end

yline(cfg.x_target_ref_km, '--k', 'LineWidth', 1.2, ...
    'DisplayName', sprintf('%d km floor', cfg.x_target_ref_km));
xline(cfg.t_push_days, ':',  'LineWidth', 1.0, 'Color', [0.4 0.4 0.4], ...
    'HandleVisibility','off');

xlabel('Active IBD operating time [days]');
ylabel('Along-track deflection at encounter [km]');
sgtitle({ ...
    'Deflection vs IBD Operating Time', ...
    sprintf('(D = %.0f m, \\rho = %.0f kg/m^3, fixed t_{enc} = %.2f yr)', ...
        2*R_ast, rho, cfg.t_enc_years)}, ...
    'FontSize', 11, 'FontWeight', 'bold');
legend('Location', 'best');
hold off;

%% -------------------- G) Figure 2 — Deflection vs stand-off distance --------------------
figure; hold on; grid on;

Cdef2 = lines(numel(cfg.t_push_list_days));

for i = 1:numel(cfg.t_push_list_days)
    t_push_i = cfg.t_push_list_days(i);
    x_km     = zeros(size(cfg.d_vec_m));

    for j = 1:numel(cfg.d_vec_m)
        ptmp = deflection_point(cfg.d_vec_m(j), t_push_i, ...
                                cfg.t_drift_years, mis, orb);
        x_km(j) = ptmp.x_def_km;
    end

    plot(cfg.d_vec_m, x_km, 'LineWidth', 2.0, 'Color', Cdef2(i,:), ...
        'DisplayName', sprintf('%d days', t_push_i));
end

yline(cfg.x_target_ref_km, '--k', 'LineWidth', 1.2, ...
    'DisplayName', sprintf('%d km floor', cfg.x_target_ref_km));
add_standoff_band(cfg.d_band_m);

xlabel('Stand-off distance [m]');
ylabel('Along-track deflection at encounter [km]');
sgtitle({ ...
    'Deflection vs Stand-off Distance', ...
    sprintf('(D = %.0f m, \\rho = %.0f kg/m^3, drift = %.1f yr)', ...
        2*R_ast, rho, cfg.t_drift_years)}, ...
    'FontSize', 11, 'FontWeight', 'bold');
legend('Location', 'northeast');
hold off;

%% -------------------- H) Figure 3 — Period change vs stand-off distance --------------------
figure; hold on; grid on;

d_vec_per  = linspace(0, 1000, 400);
t_push_per = 90;   % fixed push duration for this plot [days]
deltaT_s   = zeros(size(d_vec_per));

for j = 1:numel(d_vec_per)
    ptmp = deflection_point(d_vec_per(j), t_push_per, ...
                            cfg.t_drift_years, mis, orb);
    deltaT_s(j) = ptmp.delta_T_s;
end

plot(d_vec_per, deltaT_s, 'LineWidth', 2);
xlabel('Stand-off distance [m]');
ylabel('Orbital period change \DeltaT [s]');
sgtitle({ ...
    'Change in Asteroid Orbital Period vs Stand-off Distance', ...
    sprintf('(IBD duration = %d days)', t_push_per)}, ...
    'FontSize', 11, 'FontWeight', 'bold');
hold off;

%% -------------------- I) Figure 4 — Arrival-time shift vs IBD duration --------------------
% Arrival-time lag at encounter = x_def / v_helio.
figure; hold on; grid on;

t_vec_arr       = linspace(1, 365, 250);
arr_shift_s_vec = zeros(size(t_vec_arr));

for j = 1:numel(t_vec_arr)
    ptmp = deflection_point(cfg.d_ref_m, t_vec_arr(j), ...
                            cfg.t_drift_years, mis, orb);
    arr_shift_s_vec(j) = ptmp.x_def_m / v_helio_ms;
end

plot(t_vec_arr, arr_shift_s_vec, 'LineWidth', 2);
xlabel('IBD operating time [days]');
ylabel('Arrival-time shift at encounter [s]');
sgtitle({ ...
    'Arrival-Time Shift vs IBD Operating Duration', ...
    sprintf('(d = %.0f m, D = %.0f m, drift = %.1f yr)', ...
        cfg.d_ref_m, 2*R_ast, cfg.t_drift_years)}, ...
    'FontSize', 11, 'FontWeight', 'bold');
hold off;

%% -------------------- J) Figure 5 — Required Δv vs warning time --------------------
% Phase-drift inversion: Δv_req = x_target / (3·t_warn).
% This is the secular, tangentially-applied equivalent of Eq. (6-5).

figure; hold on; grid on;

t_warn_years = cfg.t_warn_vec_years;
t_warn_s     = t_warn_years * 365.25 * 86400;
C5 = lines(numel(cfg.x_target_km_list));

for i = 1:numel(cfg.x_target_km_list)
    x_m        = cfg.x_target_km_list(i) * 1000;
    dv_req_mms = (x_m ./ (3 * t_warn_s)) * 1000;   % [mm/s]

    plot(t_warn_years, dv_req_mms, 'LineWidth', 2, 'Color', C5(i,:), ...
        'DisplayName', sprintf('%d km', cfg.x_target_km_list(i)));
end

yline(dv_target*1000, '--k', 'LineWidth', 1.2, ...
    'DisplayName', sprintf('ESCUT Δv = %.0f mm/s', dv_target*1000));

xlabel('Warning time before encounter [years]');
ylabel('Required \Deltav [mm/s]');
sgtitle('Required Asteroid \Deltav vs Warning Time', ...
    'FontSize', 11, 'FontWeight', 'bold');
legend('Location', 'northeast');
hold off;

%% -------------------- K) Figure 6 — Required IBD operating time vs warning time --------------------
% Solve Δx = 3·a_ast·t_push·t_warn for t_push at each warning time.
% (Since Δv = a_ast·t_push, this is the push duration needed to deliver
% the required Δv_req = x_target / (3·t_warn) at the reference accel.)

figure; hold on; grid on;

% Asteroid acceleration at the reference stand-off (independent of push time)
pt_ref = deflection_point(cfg.d_ref_m, 1, cfg.t_drift_years, mis, orb);
a_ref  = pt_ref.a_ast_ms2;

C6 = lines(numel(cfg.x_target_km_list_ops));

for i = 1:numel(cfg.x_target_km_list_ops)
    x_m        = cfg.x_target_km_list_ops(i) * 1000;
    t_push_req = nan(size(t_warn_years));

    for j = 1:numel(t_warn_years)
        td_s = t_warn_years(j) * 365.25 * 86400;
        if a_ref > 0 && td_s > 0
            tp_s = x_m / (3 * a_ref * td_s);
            t_push_req(j) = tp_s / 86400;
        end
    end

    plot(t_warn_years, t_push_req, 'LineWidth', 2, 'Color', C6(i,:), ...
        'DisplayName', sprintf('%d km target', cfg.x_target_km_list_ops(i)));
end

yline(cfg.t_push_days, '--k', 'LineWidth', 1.2, ...
    'DisplayName', sprintf('ESCUT %d-day burn', cfg.t_push_days));

xlabel('Warning time before encounter [years]');
ylabel('Required IBD operating time [days]');
sgtitle({ ...
    'Required IBD Operating Time vs Warning Time', ...
    sprintf('(d = %.0f m, D = %.0f m, \\rho = %.0f kg/m^3)', ...
        cfg.d_ref_m, 2*R_ast, rho)}, ...
    'FontSize', 11, 'FontWeight', 'bold');
legend('Location', 'northeast');
hold off;

%% =========================================================================
%% LOCAL FUNCTIONS
%% =========================================================================

function pt = deflection_point(d_m, t_push_days, t_drift_years, mis, orb)
% Compute the full deflection chain at a single operating point.
%
%   d_m            stand-off distance [m]
%   t_push_days    active IBD duration [days]
%   t_drift_years  post-burn drift time (coast to encounter) [years]
%   mis            mission parameters (theta_deg, T_total_N, R_ast,
%                  rho, surface, incident_deg)
%   orb            orbital constants (mu_sun, a_helio_m, v_helio_ms,
%                  T_helio_s)
%
% Returns a struct pt with all intermediate and final quantities.

% Asteroid mass (uniform sphere)
m_ast = mis.rho * (4/3) * pi * mis.R_ast^3;

% Beam geometry and coupling at this stand-off
r_beam = max(d_m, 1e-6) * tand(mis.theta_deg);
A_beam = pi * r_beam^2;
A_ast  = pi * mis.R_ast^2;

eta_geom = min(1, A_ast / A_beam);
if d_m == 0, eta_geom = 1; end

eta_total = eta_geom * mis.surface * cosd(mis.incident_deg);
eta_total = max(min(eta_total, 1), 0);

% Effective thrust and asteroid acceleration
T_eff_N   = mis.T_total_N * eta_total;
a_ast_ms2 = T_eff_N / m_ast;

% Time conversions
t_push_s  = t_push_days   * 86400;
t_drift_s = t_drift_years * 365.25 * 86400;

% Delivered Δv (constant-thrust assumption over the burn)
dv_ms = a_ast_ms2 * t_push_s;

% Heliocentric orbital response to a tangential impulse.
%   Vis-viva :  Δa = 2 a Δv / v
%   Kepler   :  ΔT = 3 T Δv / v
delta_a_m = 2 * orb.a_helio_m  * dv_ms / orb.v_helio_ms;
delta_T_s = 3 * orb.T_helio_s  * dv_ms / orb.v_helio_ms;

% Along-track deflection at encounter: phase drift accumulated over the
% post-burn coast. Matches Eq. (6-5) in §6.2.2 with Δt = t_drift.
x_def_m  = 3 * dv_ms * t_drift_s;
x_def_km = x_def_m / 1000;

% Pack outputs
pt = struct( ...
    'd_m',         d_m, ...
    't_push_days', t_push_days, ...
    't_drift_yrs', t_drift_years, ...
    'm_ast_kg',    m_ast, ...
    'eta_geom',    eta_geom, ...
    'eta_total',   eta_total, ...
    'T_eff_N',     T_eff_N, ...
    'a_ast_ms2',   a_ast_ms2, ...
    'dv_ms',       dv_ms, ...
    'delta_a_m',   delta_a_m, ...
    'delta_T_s',   delta_T_s, ...
    'x_def_m',     x_def_m, ...
    'x_def_km',    x_def_km);
end

function add_standoff_band(d_band)
% Overlay a translucent vertical band marking the preferred operating
% stand-off range on the current axes.

yl = ylim;
patch([d_band(1) d_band(2) d_band(2) d_band(1)], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.7 0.7 0.7], 'FaceAlpha', 0.15, 'EdgeColor','none', ...
      'HandleVisibility','off');
xline(d_band(1), '-', 'LineWidth', 0.9, 'Color', [0.55 0.55 0.55], ...
    'HandleVisibility','off');
xline(d_band(2), '-', 'LineWidth', 0.9, 'Color', [0.55 0.55 0.55], ...
    'HandleVisibility','off');

x_lab = 0.5 * (d_band(1) + d_band(2));
y_lab = yl(1) + 0.88*(yl(2) - yl(1));
text(x_lab, y_lab, sprintf('Preferred band (%d–%d m)', d_band(1), d_band(2)), ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize', 9, 'BackgroundColor','w', 'Margin', 2, 'Clipping','on');
end

function passfail(label, got, expected, tol_rel)
% Simple pass/fail check against a hand-calculated reference value.
rel_err = abs(got - expected) / max(abs(expected), eps);
if rel_err <= tol_rel
    tag = 'PASS';
else
    tag = 'FAIL';
end
fprintf('  %s  got %10.4f  expected %10.4f  (%.2f%%)  [%s]\n', ...
    label, got, expected, 100*rel_err, tag);
end