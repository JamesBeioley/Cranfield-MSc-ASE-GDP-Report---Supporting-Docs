%% =========================================================================
%% IBD_Plots_3.m
%% =========================================================================
% IBD Plotting Script — all report figures
%
% Purpose
%   Generate the complete figure set for the IBD work package:
%     Section 1 — Mission geometry (coupling, beam footprint)
%     Section 2 — Parametric sensitivity studies (density, thrust, size)
%     Section 3 — Two-dimensional heatmaps (duration, propellant)
%     Section 4 — Thruster performance (T-P curves, propellant per thruster)
%
% Recommended run order
%   1) IBD_Mission_Master_1.m
%   2) IBD_Thruster_Performance_2.m
%   3) IBD_Plots_3.m                <-- this script
%
% Required workspace variables
%   From IBD_Mission_Master_1:
%     d, eta_c, r_beam, A_beam, m_ast, t_days, T_eff
%     theta_deg, T0_mN, T0_num, R_ast, rho, dv_target, surface, incident_deg
%   From IBD_Thruster_Performance_2:
%     isp_next, isp_t6, isp_spt, isp_bht, isp_saf
%     TP_next, TP_t6, TP_spt, TP_bht, TP_saf
%     (or equivalently, the structured IBD.thruster workspace)
% =========================================================================

% clc;

%% =========================================================================
%% A) LOAD INPUTS
%% =========================================================================
% Pull from the structured IBD workspace if available; otherwise expect
% flat workspace variables from the upstream scripts.

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

    d      = IBD.mission.d(:).';
    eta_c  = IBD.mission.eta_geom(:).';
    r_beam = IBD.mission.r_beam(:).';
    A_beam = IBD.mission.A_beam(:).';
end

% Fail early if anything is missing
need = {'d','eta_c','r_beam','A_beam', ...
        'theta_deg','T0_mN','T0_num','R_ast','rho','dv_target','surface','incident_deg', ...
        'isp_next','isp_t6','isp_spt','isp_bht','isp_saf', ...
        'TP_next','TP_t6','TP_spt','TP_bht','TP_saf'};
for i = 1:numel(need)
    if ~exist(need{i},'var')
        error('IBD_Plots:MissingVar', ...
            'Variable "%s" not found. Run IBD_Mission_Master_1 and IBD_Thruster_Performance_2 first.', need{i});
    end
end

g0 = 9.81;

% Derived quantities
if ~exist('m_ast','var')
    m_ast = rho * (4/3) * pi * R_ast^3;
end

T0_total_N = (T0_mN * 1e-3) * T0_num;            % total produced thrust [N]
T_eff_N    = max(T0_total_N .* eta_c, 1e-12);    % effective thrust vs d [N]

%% =========================================================================
%% B) COMMON STYLE PARAMETERS
%% =========================================================================
lw_main = 2.0;     % primary curves
lw_ref  = 1.0;     % reference / boundary lines
lw_fit  = 1.8;     % fit overlays

% Global font sizes (edit here once for all plots)
fs_axes   = 11;    % axis tick labels
fs_labels = 13;    % x/y axis labels
fs_title  = 11;    % sgtitle
fs_legend = 12;    % legends
fs_cbar   = 12;    % colorbar ticks + label
fs_text   = 12;     % in-plot annotation text
fs_clabel = 12;     % contour labels

% Thruster names and colours (used in Sections 3–4)
names_thr = {'NEXT-C','T6','SPT-140','BHT-6000','PPS5000'};
Nthr      = numel(names_thr);
C_thr     = lines(Nthr);

% Isp and TP slope vectors (same order as names_thr)
Isp_vec = [isp_next, isp_t6, isp_spt, isp_bht, isp_saf];
TP_vec  = [TP_next,  TP_t6,  TP_spt,  TP_bht,  TP_saf];

%% =========================================================================
%% SECTION 1 — MISSION GEOMETRY
%% =========================================================================

%% ---- 1.1  Geometric coupling vs stand-off distance (SV19 size range) ---
figure; hold on; grid on;

% SV19 diameter range: 20–60 m
R_min = 10;   % D = 20 m
R_nom = 20;   % D = 40 m
R_max = 30;   % D = 60 m

theta_rad = deg2rad(theta_deg);
d_safe    = max(d, 1e-6);
r_beam_d  = d_safe .* tan(theta_rad);

% Coupling for each size
eta_min = min(1, (R_min^2) ./ (r_beam_d.^2));
eta_nom = min(1, (R_nom^2) ./ (r_beam_d.^2));
eta_max = min(1, (R_max^2) ./ (r_beam_d.^2));

eta_min(d == 0) = 1;
eta_nom(d == 0) = 1;
eta_max(d == 0) = 1;

eta_min = eta_min .* surface .* cosd(incident_deg);
eta_nom = eta_nom .* surface .* cosd(incident_deg);
eta_max = eta_max .* surface .* cosd(incident_deg);

eta_min = max(min(eta_min, 1), 0);
eta_nom = max(min(eta_nom, 1), 0);
eta_max = max(min(eta_max, 1), 0);

% Shaded SV19 band
x = d(:);
hBand = fill([x; flipud(x)], [eta_min(:); flipud(eta_max(:))], ...
    [0.7 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.25, ...
    'DisplayName', 'SV19 size range: D = 20–60 m');

% Boundary curves
plot(d, eta_min, 'k--', 'LineWidth', lw_ref, ...
    'Color', [0.35 0.35 0.35], 'HandleVisibility', 'off');
plot(d, eta_max, 'k--', 'LineWidth', lw_ref, ...
    'Color', [0.35 0.35 0.35], 'HandleVisibility', 'off');

% Nominal curve
hNom = plot(d, eta_nom, 'k-', 'LineWidth', lw_main, ...
    'DisplayName', 'Nominal: D = 40 m');

% Nominal crossover distance (geometric footprint transition)
%d_cross_nom = R_nom / tand(theta_deg);

%hCross = xline(d_cross_nom, '--', ...
    %'LineWidth', 1.6, ...
    %'Color', [0.1 0.1 0.1], ...
    %'DisplayName', sprintf('d_{cross} = %.0f m', d_cross_nom));

% Labels on band edges (moved left)
x_label_pos = 120;
[~, ix] = min(abs(d - x_label_pos));

text(d(ix), eta_min(ix) + 0.02, 'D = 20 m', ...
    'FontSize', fs_text, ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'bottom', ...
    'BackgroundColor', 'w', 'Margin', 2);

text(d(ix), eta_max(ix) - 0.02, 'D = 60 m', ...
    'FontSize', fs_text, ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'Margin', 2);

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Geometric coupling efficiency \eta_{geom}', 'FontSize', fs_labels);
% sgtitle({ ...
    %'Geometric Coupling vs Stand-off Distance', ...
    %sprintf('SV19 size range: D = 20–60 m (\\theta = %.0f°)', theta_deg)}, ...
    %'FontSize', fs_title, 'FontWeight', 'bold');

lgd = legend([hBand hNom], 'Location', 'northeast');
set(lgd, 'FontSize', fs_legend);
set(gca, 'FontSize', fs_axes);

ylim([0 1]);

hold off;

%% ---- 1.2  Beam geometry: radius and area (dual-axis) ------------------
figure; hold on; grid on;

yyaxis left
plot(d, r_beam, '-', 'LineWidth', lw_main);
ylabel('Beam radius [m]', 'FontSize', fs_labels);
yline(R_ast, '--', 'LineWidth', lw_ref, 'Color', [0.5 0.5 0.5]);

yyaxis right
plot(d, A_beam, '-', 'LineWidth', lw_main);
ylabel('Beam area [m^2]', 'FontSize', fs_labels);

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
sgtitle(sprintf('Beam Footprint vs Stand-off Distance (\\theta = %.0f°)', theta_deg), ...
    'FontSize', fs_title, 'FontWeight', 'bold');

set(gca, 'FontSize', fs_axes);
hold off;

%% =========================================================================
%% SECTION 2 — PARAMETRIC SENSITIVITY STUDIES
%% =========================================================================

%% ---- 2.1  Density sensitivity ------------------------------------------
figure; hold on; grid on;

rho_list = [1500 2500 3500];

t_days_rho = zeros(numel(rho_list), numel(d));
for i = 1:numel(rho_list)
    m_i = rho_list(i) * (4/3) * pi * R_ast^3;
    t_days_rho(i,:) = (dv_target * m_i) ./ T_eff_N / 86400;
end

% Shaded band
x = d(:);
hBand = fill([x; flipud(x)], [t_days_rho(1,:).'; flipud(t_days_rho(3,:).')], ...
    [0.7 0.7 0.7], 'EdgeColor','none', 'FaceAlpha',0.25, ...
    'DisplayName', sprintf('Density range: %d–%d kg/m^3', rho_list(1), rho_list(end)));

% Boundary lines
plot(d, t_days_rho(1,:), 'k--', 'LineWidth', lw_ref, ...
    'Color', [0 0 0 0.35], 'HandleVisibility','off');
plot(d, t_days_rho(3,:), 'k--', 'LineWidth', lw_ref, ...
    'Color', [0 0 0 0.35], 'HandleVisibility','off');

% Nominal curve
hNom = plot(d, t_days_rho(2,:), 'k-', 'LineWidth', lw_main, ...
    'DisplayName', sprintf('Average \\rho = %d kg/m^3', rho_list(2)));

% In-plot labels placed mid-plot and inside band
xL = 450;
[~, ix] = min(abs(d - xL));

% Lower boundary: rho = 1500
text(d(ix), t_days_rho(1,ix)*1.03, sprintf('\\rho = %d', rho_list(1)), ...
    'FontSize', fs_text, ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'bottom', ...
    'BackgroundColor', 'w', 'Margin', 2);

% Upper boundary: rho = 3500
text(d(ix), t_days_rho(3,ix)*0.97, sprintf('\\rho = %d', rho_list(end)), ...
    'FontSize', fs_text, ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'Margin', 2);

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Time to impart target \Deltav [days]', 'FontSize', fs_labels);
ylim([0 1000]);
%sgtitle({ ...
    %'IBD Duration vs Asteroid Density and Stand-off Distance', ...
    %sprintf('(T = %.0f mN, N = %d, R = %.0f m)', T0_mN, T0_num, R_ast)}, ...
    %'FontSize', fs_title, 'FontWeight', 'bold');

lgd = legend([hBand hNom], 'Location','best');
set(lgd, 'FontSize', fs_legend);
set(gca, 'FontSize', fs_axes);

hold off;

%% ---- 2.2  Thrust sensitivity -------------------------------------------
figure; hold on; grid on;

T_low_mN  = 50;
T_high_mN = 200;

T_eff_low  = max((T_low_mN  * 1e-3 * T0_num) .* eta_c, 1e-12);
T_eff_nom  = max((T0_mN     * 1e-3 * T0_num) .* eta_c, 1e-12);
T_eff_high = max((T_high_mN * 1e-3 * T0_num) .* eta_c, 1e-12);

% Note: higher thrust => shorter time, so labels are swapped physically
t_fast_days = (dv_target * m_ast) ./ T_eff_high / 86400;   % lower boundary
t_slow_days = (dv_target * m_ast) ./ T_eff_low  / 86400;   % upper boundary
t_nom_days  = (dv_target * m_ast) ./ T_eff_nom  / 86400;

% Shaded band
x = d(:);
hBand = fill([x; flipud(x)], [t_fast_days(:); flipud(t_slow_days(:))], ...
    [0.7 0.7 0.7], 'EdgeColor','none', 'FaceAlpha',0.25, ...
    'DisplayName', sprintf('Thrust range: %d–%d mN per thruster', T_low_mN, T_high_mN));

% Boundary lines
plot(d, t_fast_days, 'k--', 'LineWidth', lw_ref, ...
    'Color', [0.35 0.35 0.35], 'HandleVisibility','off');
plot(d, t_slow_days, 'k--', 'LineWidth', lw_ref, ...
    'Color', [0.35 0.35 0.35], 'HandleVisibility','off');

% Nominal curve
hNom = plot(d, t_nom_days, 'k-', 'LineWidth', lw_main, ...
    'DisplayName', sprintf('Nominal: %.0f mN per thruster', T0_mN));

% In-plot labels placed mid-plot and inside band
xL = 450;
[~, ix] = min(abs(d - xL));

% Lower boundary: high thrust
text(d(ix), t_fast_days(ix)*1.03, sprintf('%d mN', T_high_mN), ...
    'FontSize', fs_text, ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'bottom', ...
    'BackgroundColor', 'w', 'Margin', 2);

% Upper boundary: low thrust
text(d(ix), t_slow_days(ix)*0.97, sprintf('%d mN', T_low_mN), ...
    'FontSize', fs_text, ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'Margin', 2);

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Time to impart target \Deltav [days]', 'FontSize', fs_labels);
ylim([0 1000]);
%sgtitle({ ...
    %'IBD Duration vs Thrust Level and Stand-off Distance', ...
    %sprintf('(N = %d, R = %.0f m, \\rho = %.0f kg/m^3)', T0_num, R_ast, rho)}, ...
    %'FontSize', fs_title, 'FontWeight', 'bold');

lgd = legend([hBand hNom], 'Location','northwest');
set(lgd, 'FontSize', fs_legend);
set(gca, 'FontSize', fs_axes);

hold off;

%% ---- 2.3  Size sensitivity (coupling recomputed per radius) -----------
%  When the asteroid radius changes, the geometric coupling also changes:
%  a smaller asteroid intercepts less of the beam at a given stand-off.
%  Both mass and coupling are varied consistently here.

figure; hold on; grid on;

rho_fixed = 3500;
R_min     = 10;    % D = 20 m
R_nom     = 20;    % D = 40 m
R_max     = 30;    % D = 60 m

theta_rad = deg2rad(theta_deg);
d_safe    = max(d, 1e-6);
r_beam_d  = d_safe .* tan(theta_rad);

for R_i = [R_min, R_nom, R_max]
    eta_i = min(1, (R_i^2) ./ (r_beam_d.^2));
    eta_i(d == 0) = 1;
    eta_i = eta_i .* surface .* cosd(incident_deg);
    eta_i = max(min(eta_i, 1), 0);

    T_eff_i = max(T0_total_N .* eta_i, 1e-12);
    m_i     = rho_fixed * (4/3) * pi * R_i^3;

    t_i = (dv_target * m_i) ./ T_eff_i / 86400;

    if R_i == R_min
        t_low_days = t_i;     % lower boundary
    elseif R_i == R_nom
        t_nom_days = t_i;
    else
        t_high_days = t_i;    % upper boundary
    end
end

% Shaded band
x = d(:);
hBand = fill([x; flipud(x)], [t_low_days(:); flipud(t_high_days(:))], ...
    [0.6 0.6 0.6], 'EdgeColor','none', 'FaceAlpha',0.25, ...
    'DisplayName', sprintf('Size range: D = %d–%d m', 2*R_min, 2*R_max));

% Boundary lines
plot(d, t_low_days,  'k--', 'LineWidth', lw_ref, ...
    'Color', [0.3 0.3 0.3], 'HandleVisibility','off');
plot(d, t_high_days, 'k--', 'LineWidth', lw_ref, ...
    'Color', [0.3 0.3 0.3], 'HandleVisibility','off');

% Nominal curve
hNom = plot(d, t_nom_days, 'k-', 'LineWidth', lw_main, ...
    'DisplayName', sprintf('Average: D = %d m', 2*R_nom));

% In-plot labels placed mid-plot and inside band
xL = 450;
[~, ix] = min(abs(d - xL));

% Lower boundary: D = 20 m
text(d(ix), t_low_days(ix)*1.03, sprintf('D = %d m', 2*R_min), ...
    'FontSize', fs_text, ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'bottom', ...
    'BackgroundColor', 'w', 'Margin', 2);

% Upper boundary: D = 60 m
text(d(ix), t_high_days(ix)*0.97, sprintf('D = %d m', 2*R_max), ...
    'FontSize', fs_text, ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'Margin', 2);

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Time to impart target \Deltav [days]', 'FontSize', fs_labels);
ylim([0 1000]);
%sgtitle({ ...
    %'IBD Duration vs Asteroid Size and Stand-off Distance', ...
    %sprintf('(\\rho = %d kg/m^3, T = %.0f mN, N = %d)', rho_fixed, T0_mN, T0_num)}, ...
    %'FontSize', fs_title, 'FontWeight', 'bold');

lgd = legend([hBand hNom], 'Location','northwest');
set(lgd, 'FontSize', fs_legend);
set(gca, 'FontSize', fs_axes);

hold off;

%% =========================================================================
%% SECTION 3 — TWO-DIMENSIONAL HEATMAPS
%% =========================================================================
% All three heatmaps share the same coupling computation, extracted into the
% local helper function ibd_time_grid (defined at end of script).

D_hm   = logspace(log10(2), log10(1000), 240);   % diameter grid [m]
R_hm   = D_hm / 2;                               % radius [m]
d_hm   = linspace(0, 1000, 801);                 % stand-off grid [m]

% Compute the base time-to-dv grid [seconds] — coupling recomputed per R
t_grid_s = ibd_time_grid(R_hm, d_hm, theta_deg, T0_total_N, rho, dv_target, surface, incident_deg);

% SV19 diameter band annotation parameters
D_band = [20 60];

%% ---- 3.1  Duration heatmap --------------------------------------------
figure; hold on;

Z = t_grid_s / 86400;    % [days]
Z(Z <= 0) = NaN;

[XX, YY] = meshgrid(D_hm, d_hm);
surf(XX, YY, zeros(size(Z)), Z, 'EdgeColor','none', 'FaceColor','interp');
view(2);

set(gca, 'YDir','normal', 'XScale','log', 'ColorScale','log', 'Layer','top');
grid on;

colormap(flipud(parula));
cb = colorbar;
cb.Label.String = 'Time to impart target \Deltav [days]';
cb.Label.FontSize = fs_cbar;
cb.FontSize = fs_cbar;
cb.Ticks = [1 10 100 1000 10000];
cb.TickLabels = {'1','10','100','1,000','10,000'};

xticks([10 100 1000]); xticklabels({'10','100','1000'});

xlabel('Asteroid diameter [m]', 'FontSize', fs_labels);
ylabel('Stand-off distance [m]', 'FontSize', fs_labels);
sgtitle({ ...
    'IBD Duration vs Asteroid Size and Stand-off Distance', ...
    sprintf('(T = %.0f mN per thruster, N = %d, \\rho = %d kg/m^3)', T0_mN, T0_num, rho)}, ...
    'FontSize', fs_title, 'FontWeight', 'bold');

% SV19 band
add_diameter_band(D_band, 'SV19: 20–60 m', fs_text);

% Contours
levels_days = [1 7 30 90 365];
[Cmat, hC] = contour(XX, YY, Z, levels_days, 'LineColor','k', 'LineWidth', 1.2);
clabel(Cmat, hC, 'Color','k', 'FontSize', fs_clabel, 'LabelSpacing', 500);
uistack(hC, 'top');

set(gca, 'FontSize', fs_axes);
hold off;

%% ---- 3.2  Propellant heatmap (beam only, NEXT-C Isp) ------------------
figure; hold on;

Isp_beam_hm = isp_next;
mdot_beam_hm = T0_total_N / (g0 * Isp_beam_hm);

Z = mdot_beam_hm .* t_grid_s;   % [kg]
Z(Z <= 0) = NaN;

surf(XX, YY, zeros(size(Z)), Z, 'EdgeColor','none', 'FaceColor','interp');
view(2);

set(gca, 'YDir','normal', 'XScale','log', 'ColorScale','log', 'Layer','top');
grid on;

colormap(flipud(parula));
cb = colorbar;
cb.Label.String = 'Beam propellant required [kg]';
cb.Label.FontSize = fs_cbar;
cb.FontSize = fs_cbar;
cb.Ticks = [10 100 1000 10000];
cb.TickLabels = {'10','100','1,000','10,000'};

xticks([10 100 1000]); xticklabels({'10','100','1000'});

xlabel('Asteroid diameter [m]', 'FontSize', fs_labels);
ylabel('Stand-off distance [m]', 'FontSize', fs_labels);
sgtitle({ ...
    'IBD Beam Propellant vs Asteroid Size and Stand-off Distance', ...
    sprintf('(T = %.0f mN, N = %d, I_{sp} = %.0f s)', T0_mN, T0_num, Isp_beam_hm)}, ...
    'FontSize', fs_title, 'FontWeight', 'bold');

levels_kg = [10 50 100 500 1000 5000];
[Cmat, hC] = contour(XX, YY, Z, levels_kg, 'LineColor','k', 'LineWidth', 1.2);
clabel(Cmat, hC, 'FontSize', fs_clabel, 'Color','k', 'LabelSpacing', 850);
uistack(hC, 'top');

set(gca, 'FontSize', fs_axes);
hold off;

%% ---- 3.3  Propellant heatmap (beam + counter) -------------------------
figure; hold on;

% Counter-thrust configuration for this plot
Isp_beam_hm    = isp_next;
Isp_counter_hm = isp_spt;
N_counter_hm   = 1;
counter_factor = 1.0;      % counter thrust = factor * total beam thrust

mdot_beam_hm    = T0_total_N / (g0 * Isp_beam_hm);
T_counter_N     = counter_factor * T0_total_N;
mdot_counter_hm = T_counter_N / (g0 * Isp_counter_hm);
mdot_total_hm   = mdot_beam_hm + mdot_counter_hm;

Z = mdot_total_hm .* t_grid_s;
Z(Z <= 0) = NaN;

surf(XX, YY, zeros(size(Z)), Z, 'EdgeColor','none', 'FaceColor','interp');
view(2);

set(gca, 'YDir','normal', 'XScale','log', 'ColorScale','log', 'Layer','top');
grid on;

colormap(flipud(parula));
cb = colorbar;
cb.Label.String = 'Total propellant (beam + counter) [kg]';
cb.Label.FontSize = fs_cbar;
cb.FontSize = fs_cbar;
cb.Ticks = [10 100 1000 10000 100000];
cb.TickLabels = {'10','100','1,000','10,000','100,000'};

xticks([10 100 1000]); xticklabels({'10','100','1000'});

xlabel('Asteroid diameter [m]', 'FontSize', fs_labels);
ylabel('Stand-off distance [m]', 'FontSize', fs_labels);
%sgtitle({ ...
    %'IBD Total Propellant (Beam + Counter) vs Size and Stand-off', ...
    %sprintf('(Beam: %d\\times%.0f mN, I_{sp}=%.0f s;  Counter: %d\\times%.0f mN, I_{sp}=%.0f s)', ...
        %T0_num, T0_mN, Isp_beam_hm, N_counter_hm, 1e3*T_counter_N/N_counter_hm, Isp_counter_hm)}, ...
    %'FontSize', fs_title, 'FontWeight', 'bold');

% SV19 band
add_diameter_band(D_band, 'SV19: 20–60 m', fs_text);

levels_kg = [10 50 100 500 1000 5000];
[Cmat, hC] = contour(XX, YY, Z, levels_kg, 'LineColor','k', 'LineWidth', 1.2);
clabel(Cmat, hC, 'FontSize', fs_clabel, 'Color','k', 'LabelSpacing', 850);
uistack(hC, 'top');

set(gca, 'FontSize', fs_axes);
hold off;

%% =========================================================================
%% SECTION 4 — THRUSTER PERFORMANCE
%% =========================================================================

%% ---- 4.1  Thrust vs power: vendor data + linear fits -------------------
% Pull operating-point data from IBD.thruster if available (single source
% of truth), otherwise use the flat workspace arrays from the thruster
% performance script.

if exist('IBD','var') && isfield(IBD,'thruster')
    P_sets = IBD.thruster.P_data;
    T_sets = IBD.thruster.T_data;
else
    P_sets = {P_next, P_t6, P_spt, P_bht, P_saf};
    T_sets = {T_next, T_t6, T_spt, T_bht, T_saf};
end

figure; hold on; grid on;

fit_handles = gobjects(1, Nthr);

for k = 1:Nthr
    Pk = P_sets{k}(:);
    Tk = T_sets{k}(:);

    % Vendor data points
    plot(Pk, Tk, '-o', 'Color', C_thr(k,:), 'LineWidth', lw_main, ...
        'MarkerSize', 7, 'MarkerFaceColor','none', 'HandleVisibility','off');

    % Linear fit overlay
    p = polyfit(Pk, Tk, 1);
    Pfit = linspace(min(Pk), max(Pk), 200);

    fit_handles(k) = plot(Pfit, polyval(p, Pfit), '--', ...
        'Color', C_thr(k,:), 'LineWidth', lw_fit, ...
        'DisplayName', sprintf('%s (%.1f mN/kW)', names_thr{k}, 1000*p(1)));
end

xlabel('Input power [W]', 'FontSize', fs_labels);
ylabel('Thrust [mN]', 'FontSize', fs_labels);
xlim([0 8000]); ylim([0 350]);
% sgtitle('Thrust vs Power — Shortlisted Thrusters', 'FontSize', fs_title, 'FontWeight','bold');

lgd = legend(fit_handles, 'Location','southeast');
set(lgd, 'FontSize', fs_legend);
set(gca, 'FontSize', fs_axes);

hold off;

%% ---- 4.2  Propellant vs stand-off (one curve per thruster) -------------
% Propellant = mdot * t_req = (dv * m_ast) / (g0 * Isp * eta_c)
% Note: thrust cancels — propellant depends only on Isp and coupling.

prop_kg = zeros(Nthr, numel(d));
for k = 1:Nthr
    prop_kg(k,:) = (dv_target * m_ast) ./ (g0 * Isp_vec(k) * eta_c);
end

figure; hold on; grid on;
for k = 1:Nthr
    plot(d, prop_kg(k,:), '-', 'Color', C_thr(k,:), 'LineWidth', lw_main, ...
        'DisplayName', names_thr{k});
end
xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
ylabel('Propellant required [kg]', 'FontSize', fs_labels);
sgtitle(sprintf('Beam Propellant vs Stand-off (\\Deltav = %.0e m/s, N = %d)', dv_target, T0_num), ...
    'FontSize', fs_title, 'FontWeight', 'bold');

lgd = legend('Location','best');
set(lgd, 'FontSize', fs_legend);
set(gca, 'FontSize', fs_axes);

hold off;

%% ---- 4.3  Duration + propellant vs stand-off (dual-axis) ---------------
figure; hold on; grid on;

yyaxis left
ax = gca; ax.YColor = [0 0 0];
plot(d, t_days, '-.', 'Color', [0 0 0], 'LineWidth', lw_main, 'DisplayName','Duration');
ylabel('Time to impart target \Deltav [days]', 'FontSize', fs_labels);

yyaxis right
ax.YColor = [0.3 0.3 0.3];
for k = 1:Nthr
    plot(d, prop_kg(k,:), '-', 'Color', C_thr(k,:), 'LineWidth', lw_main, ...
        'DisplayName', names_thr{k});
end
ylabel('Propellant required [kg]', 'FontSize', fs_labels);

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
sgtitle({ ...
    'Duration and Propellant vs Stand-off Distance', ...
    sprintf('(T = %.0f mN, N = %d, R = %.0f m, \\rho = %.0f kg/m^3)', T0_mN, T0_num, R_ast, rho)}, ...
    'FontSize', fs_title, 'FontWeight', 'bold');

lgd = legend('Location','best');
set(lgd, 'FontSize', fs_legend);
set(gca, 'FontSize', fs_axes);

hold off;

%% ---- 4.4  Effective thrust + propellant vs stand-off (dual-axis) -------
figure; hold on; grid on;

yyaxis left
ax = gca; ax.YColor = [0 0 0];
plot(d, 1e3*T_eff_N, '-.', 'Color', [0 0 0], 'LineWidth', lw_main, ...
    'DisplayName','Effective thrust');
ylabel('Effective thrust T_{eff} [mN]', 'FontSize', fs_labels);

yyaxis right
ax.YColor = [0.3 0.3 0.3];
for k = 1:Nthr
    plot(d, prop_kg(k,:), '-', 'Color', C_thr(k,:), 'LineWidth', lw_main, ...
        'DisplayName', names_thr{k});
end
ylabel('Propellant required [kg]', 'FontSize', fs_labels);

xlabel('Stand-off distance [m]', 'FontSize', fs_labels);
sgtitle({ ...
    'Effective Thrust and Propellant vs Stand-off Distance', ...
    sprintf('(T = %.0f mN, N = %d, R = %.0f m, \\rho = %.0f kg/m^3)', T0_mN, T0_num, R_ast, rho)}, ...
    'FontSize', fs_title, 'FontWeight', 'bold');

lgd = legend('Location','best');
set(lgd, 'FontSize', fs_legend);
set(gca, 'FontSize', fs_axes);

hold off;

%% =========================================================================
%% LOCAL HELPER FUNCTIONS
%% =========================================================================

function t_grid_s = ibd_time_grid(R_list, d_list, theta_deg, T_total_N, rho, dv_target, surface, incident_deg)
% Compute the time-to-delta-v grid [s] over stand-off and asteroid radius.
% Coupling is recomputed for each radius.

theta_rad = deg2rad(theta_deg);
d_safe    = max(d_list, 1e-6);
r_beam_d  = d_safe .* tan(theta_rad);

t_grid_s = nan(numel(d_list), numel(R_list));

for j = 1:numel(R_list)
    R = R_list(j);

    eta = min(1, R^2 ./ r_beam_d.^2);
    eta(d_list == 0) = 1;
    eta = eta .* surface .* cosd(incident_deg);
    eta = max(min(eta, 1), 0);

    T_eff = max(T_total_N .* eta, 1e-12);
    m_i   = rho * (4/3) * pi * R^3;

    t_grid_s(:,j) = (dv_target * m_i) ./ T_eff(:);
end
end

function add_diameter_band(D_band, label_str, fs_text)
% Overlay a translucent vertical band marking a diameter range on the
% current axes, with a centred text label.

yl = ylim;
patch([D_band(1) D_band(2) D_band(2) D_band(1)], ...
      [yl(1) yl(1) yl(2) yl(2)], [1 1 1], ...
      'FaceAlpha', 0.18, 'EdgeColor','none', 'HandleVisibility','off');

xline(D_band(1), '-', 'LineWidth', 0.9, 'Color', [0 0 0], 'Alpha', 0.25, 'HandleVisibility','off');
xline(D_band(2), '-', 'LineWidth', 0.9, 'Color', [0 0 0], 'Alpha', 0.25, 'HandleVisibility','off');

x_lab = sqrt(D_band(1) * D_band(2));
y_lab = yl(1) + 0.85*(yl(2) - yl(1));
text(x_lab, y_lab, label_str, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize', fs_text, 'BackgroundColor','w', 'Margin', 2, 'Clipping','on');
end