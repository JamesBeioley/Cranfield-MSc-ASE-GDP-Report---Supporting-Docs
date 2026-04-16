%% =========================================================================
%% Gradiometry_Plots_2.m
%% =========================================================================
% NEO Gravity Gradiometry — Full Figure Suite
%
% Purpose
%   Generate the complete set of report figures for the gravity gradiometry
%   analysis, including heatmaps of field strength and detectability,
%   instrument comparison contours, integration-time maps, density
%   sensitivity overlays, and 3D surface visualisations.
%
% Figures produced
%   1)  All-instrument detectability map (gradient + instrument contours)
%   2)  GOCE detectability contours (no asteroid markers)
%   3)  GOCE detectability contours (with SU49 and SV19 markers)
%   4)  GOCE instantaneous detection limit (T = 1 s)
%   5)  GOCE contour family with on-line integration-time labels
%   6)  3D surface plot (raw)
%   7)  3D surface plot (matched axis limits to 2D heatmaps)
%   8)  1D gradient vs diameter at fixed offset
%   9)  Required integration time map (GOCE)
%   10) Density sensitivity of GOCE detectability boundary
%
% Recommended run order
%   1) Gradiometry_Core_1.m
%   2) Gradiometry_Plots_2.m
% =========================================================================

if ~exist('NEO','var')
    error('Run Gradiometry_Core_1.m first.');
end

%% =========================================================================
%% A) UNPACK CORE OUTPUTS
%% =========================================================================
cfg    = NEO.cfg;
instr  = NEO.instr;
out    = NEO.point;
out2   = NEO.grid;
G      = NEO.const.G;
EOTVOS = NEO.const.EOTVOS;

D_m        = cfg.D_m;
h_km       = cfg.h_km;
SNR_target = cfg.SNR_target;

%% =========================================================================
%% B) COMMON STYLE PARAMETERS
%% =========================================================================
% Global font sizes (edit here once for all plots)
fs_axes   = 12;   % axis tick labels
fs_labels = 12;   % x/y/z axis labels
fs_title  = 12;   % sgtitle
fs_legend = 12;   % legends
fs_cbar   = 12;   % colorbar ticks + label
fs_text   = 10;   % in-plot annotation text
fs_clabel = 8;    % contour labels

stdPlot   = @() set(gcf, 'Color', 'w');
stdAxes   = @() set(gca, 'FontName', 'Arial', 'FontSize', fs_axes, ...
                         'LineWidth', 1.0, 'Box', 'on', 'Layer', 'top');
stdLegend = @(lgd) set(lgd, 'Box', 'on', 'FontSize', fs_legend);
stdCbar   = @(cb)  set(cb,  'FontSize', fs_cbar);

%% =========================================================================
%% C) SHARED SETTINGS
%% =========================================================================
kGOCE = find(strcmp([instr.name], "GOCE (in-orbit)"), 1, 'first');
if isempty(kGOCE)
    error('GOCE (in-orbit) not found in instrument database.');
end

darkred = [0.55 0.05 0.05];

% Precompute the base gradient field (positive-only for log scaling)
Z_grad = out2.gradE;
Z_grad(Z_grad <= 0) = NaN;

Zlog      = log10(Z_grad);
zlog_min  = min(Zlog(:), [], 'omitnan');
zlog_max  = max(Zlog(:), [], 'omitnan');

ymin_km = min(h_km(h_km > 0));

%% =========================================================================
%% FIGURE 1 — All-instrument detectability map
%% =========================================================================
figure; hold on; grid on;

plot_base_heatmap(D_m, h_km, Z_grad, Zlog, ymin_km);

cb = colorbar;
cb.Label.String = 'Gravity gradient |\Gamma| [E]';
cb.Label.FontSize = fs_cbar;

xlabel('Asteroid diameter [m]', 'FontSize', fs_labels);
ylabel('Surface offset [km]', 'FontSize', fs_labels);
sgtitle('Gravity Gradient Magnitude vs Asteroid Size and Offset', ...
    'FontSize', fs_title, 'FontWeight', 'bold');

Cline = lines(numel(instr));
hleg  = gobjects(numel(instr), 1);

for k = 1:numel(instr)
    GammaE_thresh = (cfg.SNR_floor * instr(k).nE) / sqrt(cfg.T_floor_s);
    lvl = log10(GammaE_thresh);

    if lvl >= zlog_min && lvl <= zlog_max
        [~, hC] = contour(D_m, h_km, Zlog, [lvl lvl], ...
            'LineWidth', 1.8, 'LineColor', Cline(k,:));
        hleg(k) = hC;
    else
        hleg(k) = plot(nan, nan, 'LineWidth', 1.8, 'Color', Cline(k,:));
    end
end

uistack(findobj(gca, 'Type', 'contour'), 'top');
lgd = legend(hleg, {instr.name}, 'Location', 'northeast');
lgd.Title.String = 'Instrument';
lgd.AutoUpdate = 'off';

stdPlot(); stdAxes(); stdLegend(lgd); stdCbar(cb);
hold off;

%% =========================================================================
%% FIGURE 2 — GOCE detectability contours (no asteroid markers)
%% =========================================================================
figure;
plot_goce_detectability_map(D_m, h_km, Z_grad, Zlog, zlog_min, zlog_max, ...
    ymin_km, instr, kGOCE, SNR_target, ...
    [60, 3600, 86400, 604800, 2629800], ...
    ["1 min", "1 hour", "1 day", "1 week", "1 month"], ...
    {'-', '--', '-.', ':','-'}, [1.5, 1.5, 1.5, 1.5, 2.5], ...
    {'Gravity Gradient vs Asteroid Size and Offset with Detectability', ...
     sprintf('Limits for GOCE-class Gradiometer (SNR = %g)', SNR_target)}, ...
    false, fs_axes, fs_labels, fs_title, fs_legend, fs_cbar, fs_text);

stdPlot(); stdAxes();

%% =========================================================================
%% FIGURE 3 — GOCE detectability contours with asteroid markers
%% =========================================================================
figure;
plot_goce_detectability_map(D_m, h_km, Z_grad, Zlog, zlog_min, zlog_max, ...
    ymin_km, instr, kGOCE, SNR_target, ...
    [60, 3600, 86400, 604800, 2629800], ...
    ["1 min", "1 hour", "1 day", "1 week", "1 month"], ...
    {'-', '--', '-.', ':', '-'}, [1.5, 1.5, 1.5, 1.5, 2.5], ...
    {'Gravity Gradient vs Asteroid Size and Offset with Detectability', ...
     sprintf('Limits for GOCE-class Gradiometer (SNR = %g)', SNR_target)}, ...
    true, fs_axes, fs_labels, fs_title, fs_legend, fs_cbar, fs_text);

sgtitle('');

stdPlot(); stdAxes();

%% =========================================================================
%% FIGURE 4 — GOCE instantaneous detection limit (T = 1 s)
%% =========================================================================
figure; hold on; grid on;

plot_base_heatmap(D_m, h_km, Z_grad, Zlog, ymin_km);

cb = colorbar;
cb.Label.String = 'Gravity gradient |\Gamma| [E]';
cb.Label.FontSize = fs_cbar;

xlabel('Asteroid diameter [m]', 'FontSize', fs_labels);
ylabel('Surface offset [km]', 'FontSize', fs_labels);

GammaE_thresh = (cfg.SNR_floor * instr(kGOCE).nE) / sqrt(1);
lvl = log10(GammaE_thresh);

if lvl >= zlog_min && lvl <= zlog_max
    contour(D_m, h_km, Zlog, [lvl lvl], ...
        'LineWidth', 1.5, 'LineStyle', '--', 'LineColor', 'k');
end

add_asteroid_markers(darkred, fs_text);

stdPlot(); stdAxes(); stdCbar(cb);
hold off;

%% =========================================================================
%% FIGURE 5 — GOCE contour family with on-line labels
%% =========================================================================
figure; hold on; grid on;

plot_base_heatmap(D_m, h_km, Z_grad, Zlog, ymin_km);

cb = colorbar;
cb.Label.String = 'Gravity gradient |\Gamma| [E]';
cb.Label.FontSize = fs_cbar;

xlabel('Asteroid diameter [m]', 'FontSize', fs_labels);
ylabel('Surface offset [km]', 'FontSize', fs_labels);
sgtitle({'Gravity Gradient Magnitude vs Asteroid Size and Offset with', ...
    'GOCE Integration-Time Contours'}, ...
    'FontSize', fs_title, 'FontWeight', 'bold');

styles = {'-', '--', ':', '-.', '-', '--'};
widths = [3.0, 2.6, 2.6, 2.6, 3.0, 3.0];
C_turbo = turbo(numel(cfg.T_GOCE_list_s));

D_label = 80;    % diameter at which to place inline labels [m]
gapPts  = 10;    % half-gap in contour points around the label

for i = 1:numel(cfg.T_GOCE_list_s)
    T_now = cfg.T_GOCE_list_s(i);
    GammaE_thresh = (cfg.SNR_floor * instr(kGOCE).nE) / sqrt(T_now);
    lvl = log10(GammaE_thresh);

    if lvl < zlog_min || lvl > zlog_max
        continue;
    end

    [Cmat, hC] = contour(D_m, h_km, Zlog, [lvl lvl], ...
        'LineWidth', widths(i), 'LineStyle', styles{i}, 'LineColor', C_turbo(i,:));
    delete(hC);

    idx = 1;
    while idx < size(Cmat, 2)
        npts = Cmat(2, idx);
        xseg = Cmat(1, idx+1:idx+npts);
        yseg = Cmat(2, idx+1:idx+npts);
        idx  = idx + npts + 1;

        if numel(xseg) < (2*gapPts + 5)
            plot(xseg, yseg, 'LineWidth', widths(i), 'LineStyle', styles{i}, 'Color', C_turbo(i,:));
            continue;
        end

        [~, j] = min(abs(xseg - D_label));
        j = max(j, gapPts + 2);
        j = min(j, numel(xseg) - gapPts - 2);

        dx  = xseg(j+1) - xseg(j-1);
        dy  = yseg(j+1) - yseg(j-1);
        ang = atan2d(dy, dx);
        if ang >  90, ang = ang - 180; end
        if ang < -90, ang = ang + 180; end

        a = max(1, j - gapPts);
        b = min(numel(xseg), j + gapPts);

        plot(xseg(1:a),   yseg(1:a),   'LineWidth', widths(i), 'LineStyle', styles{i}, 'Color', C_turbo(i,:));
        plot(xseg(b:end), yseg(b:end), 'LineWidth', widths(i), 'LineStyle', styles{i}, 'Color', C_turbo(i,:));

        t = text(xseg(j), yseg(j), cfg.T_GOCE_labels(i), ...
            'Color', C_turbo(i,:), 'FontWeight', 'normal', 'FontSize', fs_clabel, ...
            'Rotation', ang, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'Clipping', 'on');
        t.BackgroundColor = [1 1 1];
        t.Margin = 1;
    end
end

stdPlot(); stdAxes(); stdCbar(cb);
hold off;

%% =========================================================================
%% FIGURE 6 — 3D surface plot (raw)
%% =========================================================================
figure;

surf(out2.DD, out2.HH_km, log10(out2.gradE), 'EdgeColor', 'none');
set(gca, 'XScale', 'log', 'YScale', 'log');

xlabel('Asteroid diameter D [m]', 'FontSize', fs_labels);
ylabel('Surface offset h [km]', 'FontSize', fs_labels);
zlabel('log_{10}(|\Gamma|) [E]', 'FontSize', fs_labels);
sgtitle('Gravity Gradient Magnitude vs Diameter and Offset', ...
    'FontSize', fs_title, 'FontWeight', 'bold');

cb = colorbar;
cb.Label.FontSize = fs_cbar;

grid on; view(45, 30);
stdPlot(); stdAxes(); stdCbar(cb);

%% =========================================================================
%% FIGURE 7 — 3D surface plot (axis limits matched to heatmaps)
%% =========================================================================
figure;

surf(out2.DD, out2.HH_km, Zlog, 'EdgeColor', 'none');
shading interp;
set(gca, 'XScale', 'log', 'YScale', 'log');

xlim([min(D_m) max(D_m)]);
ylim([ymin_km 1e4]);
zlim([-15 3]);
clim([-15 3]);

xlabel('Asteroid diameter D [m]', 'FontSize', fs_labels);
ylabel('Surface offset h [km]', 'FontSize', fs_labels);
zlabel('log_{10}(|\Gamma|) [E]', 'FontSize', fs_labels);
sgtitle('Gravity Gradient Magnitude vs Diameter and Offset', ...
    'FontSize', fs_title, 'FontWeight', 'bold');

cb = colorbar;
cb.Label.String = 'log_{10}(|\Gamma|) [E]';
cb.Label.FontSize = fs_cbar;

grid on; view(45, 30);
stdPlot(); stdAxes(); stdCbar(cb);

%% =========================================================================
%% FIGURE 8 — 1D gradient vs diameter at fixed offset
%% =========================================================================
figure;

loglog(D_m, out.gradE, 'LineWidth', 2);
grid on;

xlabel('Asteroid diameter D [m]', 'FontSize', fs_labels);
ylabel('Gravity gradient \Gamma [E]', 'FontSize', fs_labels);
sgtitle(sprintf('Gravity Gradient vs Diameter at h = %.1f km', cfg.h0_km), ...
    'FontSize', fs_title, 'FontWeight', 'bold');

stdPlot(); stdAxes();

%% =========================================================================
%% FIGURE 9 — Required integration time map (GOCE)
%% =========================================================================
figure; hold on; grid on;

nE_GOCE = instr(kGOCE).nE;
GammaE_safe = Z_grad;

Treq_s = ((SNR_target * nE_GOCE) ./ GammaE_safe).^2;
Treq_s(~isfinite(Treq_s)) = NaN;
Treq_s(Treq_s > 1e12) = NaN;

Treq_days = Treq_s / 86400;
Treq_days(Treq_days <= 0) = NaN;

Treq_log = log10(Treq_days);

[XX, YY] = meshgrid(D_m, h_km);
surf(XX, YY, zeros(size(Treq_log)), Treq_days, 'EdgeColor', 'none', 'FaceColor', 'interp');
view(2);

set(gca, 'YDir', 'normal', 'XScale', 'log', 'YScale', 'log', 'ColorScale', 'log');
ylim([ymin_km 1e4]);
xlim([min(D_m) max(D_m)]);
clim([1e-4 1e4]);
colormap(parula);

cb = colorbar;
cb.Label.String = 'Required integration time T_{req} [days]';
cb.Label.FontSize = fs_cbar;

xlabel('Asteroid diameter D [m]', 'FontSize', fs_labels);
ylabel('Surface offset h [km]', 'FontSize', fs_labels);
sgtitle({'Required Integration Time for Detection', ...
    sprintf('GOCE-class EGG, SNR = %g', SNR_target)}, ...
    'FontSize', fs_title, 'FontWeight', 'bold');

Tcont_days = [1/1440, 1/24, 1, 7, 30];
levels = log10(Tcont_days);

[Cs, hCs] = contour(D_m, h_km, Treq_log, levels, ...
    'LineColor', 'k', 'LineWidth', 1.2);
clabel(Cs, hCs, 'Color', 'k', 'FontSize', fs_clabel, 'LabelSpacing', 350);
uistack(hCs, 'top');

stdPlot(); stdAxes(); stdCbar(cb);
hold off;

%% =========================================================================
%% FIGURE 10 — Density sensitivity of the GOCE detectability boundary
%% =========================================================================
figure; hold on; grid on;

T_rho = 60;

rho_list = [1500, 2500, 3500];
rho_lbl  = ["1500 kg/m^3 (rubble pile)", "2500 kg/m^3 (nominal)", "3500 kg/m^3 (dense/metal-rich)"];

GammaE_thresh = (SNR_target * instr(kGOCE).nE) / sqrt(T_rho);
lvl = log10(GammaE_thresh);

plot_base_heatmap(D_m, h_km, Z_grad, Zlog, ymin_km);

cb = colorbar;
cb.Label.String = 'Gravity gradient |\Gamma| [E]';
cb.Label.FontSize = fs_cbar;

xlabel('Asteroid diameter [m]', 'FontSize', fs_labels);
ylabel('Surface offset [km]', 'FontSize', fs_labels);

add_asteroid_markers(darkred, fs_text);

lineStyles = {'--', '-', '-.'};
lineWidths = [1.2, 1.2, 1.2];
Crho = lines(numel(rho_list));
hleg = gobjects(numel(rho_list), 1);

for i = 1:numel(rho_list)
    out_rho = neo_fields_2D_local(D_m, rho_list(i), h_km, G, EOTVOS);

    Zrho = out_rho.gradE;
    Zrho(Zrho <= 0) = NaN;
    Zrho_log = log10(Zrho);

    zr_min = min(Zrho_log(:), [], 'omitnan');
    zr_max = max(Zrho_log(:), [], 'omitnan');

    if lvl >= zr_min && lvl <= zr_max
        [~, hC] = contour(D_m, h_km, Zrho_log, [lvl lvl], ...
            'LineWidth', lineWidths(i), 'LineStyle', lineStyles{i}, ...
            'LineColor', Crho(i,:));
        hleg(i) = hC;
    else
        hleg(i) = plot(nan, nan, ...
            'LineWidth', lineWidths(i), 'LineStyle', lineStyles{i}, ...
            'Color', Crho(i,:));
    end
end

uistack(findobj(gca, 'Type', 'contour'), 'top');
lgd = legend(hleg, rho_lbl, 'Location', 'southeast');
lgd.Title.String = sprintf('GOCE contour: SNR = %g, T = %.0f s', SNR_target, T_rho);

stdPlot(); stdAxes(); stdLegend(lgd); stdCbar(cb);
hold off;

%% =========================================================================
%% LOCAL HELPER FUNCTIONS
%% =========================================================================

function plot_base_heatmap(D_m, h_km, Z, Zlog, ymin_km)
% Render the gradient field as a correctly-scaled colour map using surf.

[XX, YY] = meshgrid(D_m, h_km);
surf(XX, YY, zeros(size(Zlog)), Z, 'EdgeColor', 'none', 'FaceColor', 'interp');
view(2);

set(gca, 'YDir', 'normal', 'XScale', 'log', 'YScale', 'log', 'ColorScale', 'log');
clim([1e-15 1e3]);
colormap(parula);

ylim([ymin_km 1e4]);
end

function plot_goce_detectability_map(D_m, h_km, Z, Zlog, zmin, zmax, ...
    ymin_km, instr, kGOCE, SNR_target, Tlist, Tlabels, styles, widths, ttl, addAsteroids, ...
    fs_axes, fs_labels, fs_title, fs_legend, fs_cbar, fs_text)
% Plot a GOCE detectability map with selected integration-time contours.

hold on; grid on;

plot_base_heatmap(D_m, h_km, Z, Zlog, ymin_km);

cb = colorbar;
cb.Label.String = 'Gravity gradient |\Gamma| [E]';
cb.Label.FontSize = fs_cbar;

xlabel('Asteroid diameter [m]', 'FontSize', fs_labels);
ylabel('Surface offset [km]', 'FontSize', fs_labels);
sgtitle(ttl, 'FontSize', fs_title, 'FontWeight', 'bold');

h_lines = gobjects(numel(Tlist), 1);

for i = 1:numel(Tlist)
    GammaE_thresh = (SNR_target * instr(kGOCE).nE) / sqrt(Tlist(i));
    lvl = log10(GammaE_thresh);

    if lvl < zmin || lvl > zmax
        h_lines(i) = plot(nan, nan, 'LineWidth', widths(i), ...
            'LineStyle', styles{i}, 'Color', 'k');
    else
        [~, hC] = contour(D_m, h_km, Zlog, [lvl lvl], ...
            'LineWidth', widths(i), 'LineStyle', styles{i}, ...
            'LineColor', 'k', 'DisplayName', Tlabels(i));
        h_lines(i) = hC;
    end
end

if addAsteroids
    add_asteroid_markers([0.55 0.05 0.05], fs_text);
end

lgd = legend(h_lines, 'Location', 'southeast');
lgd.Title.String = 'Integration Time';

set(gcf, 'Color', 'w');
set(gca, 'FontName', 'Arial', 'FontSize', fs_axes, 'LineWidth', 1.0, 'Box', 'on', 'Layer', 'top');
set(lgd, 'Box', 'on', 'FontSize', fs_legend);
set(cb,  'FontSize', fs_cbar);

hold off;
end

function add_asteroid_markers(darkred, fs_text)
% Overlay markers for the two target asteroids: 2006 SU49 and 2017 SV19.

yl = ylim;
y_label = 10^(log10(yl(1)) + 0.7*(log10(yl(2)) - log10(yl(1))));

% 2006 SU49 (D = 377 m)
D_SU49 = 377;
xline(D_SU49, 'Color', darkred, 'LineWidth', 1.25);
text(D_SU49*1.15, y_label, '2006 SU49 (377 m)', ...
    'Rotation', 90, 'FontSize', fs_text, 'FontWeight', 'bold', ...
    'BackgroundColor', 'w', 'Margin', 2, 'HorizontalAlignment', 'left');

% 2017 SV19 (D = 20-60 m)
D_min = 20;  D_max = 60;
patch([D_min D_max D_max D_min], [yl(1) yl(1) yl(2) yl(2)], ...
    [0.6 0.6 0.6], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
xline(D_min, 'Color', darkred, 'LineWidth', 0.8);
xline(D_max, 'Color', darkred, 'LineWidth', 0.8);
text(30, y_label, '2017 SV19 (20–60 m)', ...
    'Rotation', 90, 'FontSize', fs_text, 'FontWeight', 'bold', ...
    'BackgroundColor', 'w', 'Margin', 2, 'HorizontalAlignment', 'left');
end

function out = neo_fields_2D_local(D_m, rho, h_km, G, EOTVOS)
% Lightweight 2D field computation for density-sensitivity overlays.

[DD, HH] = meshgrid(D_m, h_km);

R_m  = DD / 2;
M_kg = (4/3) * pi .* R_m.^3 .* rho;
r_m  = R_m + HH * 1000;

g_ms2   = G .* M_kg ./ r_m.^2;
grad_s2 = 2 .* g_ms2 ./ r_m;

out.gradE = grad_s2 ./ EOTVOS;
end