%% NEO_TradeSpace_Sensitivity.m
% =========================================================================
% NEO Pathfinder GDP — Trade Space Sensitivity Analysis
% Covers: (A) IBD Deflection Methods Trade Study
%         (B) Gravity Gradiometry Instrument Trade Study
%
% Three analyses per trade study:
%   1. One-at-a-time (OAT) weight perturbation  (+/- 0.05)
%   2. Monte Carlo sampling (Dirichlet, N draws)
%   3. Threshold analysis (single-criterion sweep)
%
% Assumptions:
%   - Scores are fixed at values in revised trade-off tabs (March 2026)
%   - Weights are redistributed proportionally when one criterion is varied
%   - Monte Carlo uses uniform Dirichlet (alpha=1): no prior on weights
%   - OAT redistribution is proportional to remaining weights
%
% References:
%   Bombardelli & Pelaez (2011), Acta Astronautica — IBD concept
%   Lu & Love (2005), Nature — Gravity Tractor
%   GOCE Mission Report, ESA (2014) — Electrostatic gradiometer heritage
%
% Run order: Run as a single script. Figures auto-numbered 1–6.
% Output:    Console tables + 6 figures (save manually or add print cmds)
%
% Author:    James [Surname] — Cranfield MSc Astronautics, NEO Pathfinder GDP
% Date:      March 2026
% =========================================================================

clc; clear; close all;

rng(42);  % Reproducibility

%% =========================================================================
%  A. DEFINE TRADE STUDY DATA
%  =========================================================================

% ── A1. IBD Deflection Methods ────────────────────────────────────────────
% Criteria: TRL | ΔV Potential | Timescale | Power | Controllability |
%           Dependence on NEO | Political/Legal | Measurability
IBD.criteria = {'TRL', 'ΔV Potential', 'Timescale', 'Power', ...
                'Controllability', 'Dependence', 'Political', 'Measurability'};

IBD.methods = {'Ion Beam Deflection', 'Kinetic Impactor', ...
               'Enhanced Gravity Tractor', 'Gravity Tractor', ...
               'Tethered Space Tug', 'Laser Ablation', ...
               'Nuclear Explosive Device', 'Mass Driver', ...
               'Surface Modification'};

% Rows = methods, Cols = criteria  (scores 1–5)
IBD.scores = [
    3  4  4  4  4  5  4  5;   % Ion Beam Deflection
    5  4  4  5  3  2  3  3;   % Kinetic Impactor
    2  2  2  4  5  4  5  4;   % Enhanced Gravity Tractor
    3  2  1  4  5  4  5  4;   % Gravity Tractor
    1  3  3  4  5  2  5  4;   % Tethered Space Tug
    2  3  4  2  4  2  3  4;   % Laser Ablation
    4  5  5  5  1  1  1  2;   % Nuclear Explosive Device
    1  3  3  3  3  1  3  2;   % Mass Driver
    1  1  1  5  3  2  5  2;   % Surface Modification
];

IBD.w_base = [0.10 0.15 0.15 0.1 0.15 0.15 0.05 0.15];
IBD.winner = 'Ion Beam Deflection';
IBD.label  = 'IBD Deflection Methods';

% ── A2. Gravity Gradiometry Instruments ──────────────────────────────────
% Criteria: TRL | Sensitivity | Integration Time | Power |
%           Platform Stability | Environmental Robustness | Data Integration
NEO.criteria = {'TRL', 'Sensitivity', 'Int. Time (SNR≥5)', 'Power', ...
                'Platform Stability', 'Env. Robustness', 'Data Integration'};

NEO.methods = {'Electrostatic (GOCE)', 'Superconducting (sci-grade)', ...
               'Superconducting (lab)', 'Quantum (sci-grade)', ...
               'Quantum (lab)'};

NEO.scores = [
    5  3  4  4  2  3  5;   % Electrostatic
    1  5  5  2  2  3  4;   % Superconducting (sci-grade)
    2  4  4  2  2  2  3;   % Superconducting (lab)
    1  4  5  2  1  2  3;   % Quantum (sci-grade)
    2  3  2  2  1  1  2;   % Quantum (lab)
];

NEO.w_base = [0.15 0.25 0.15 0.10 0.10 0.15 0.10];
NEO.winner = 'Electrostatic (GOCE)';
NEO.label  = 'Gradiometry Instruments';

%% =========================================================================
%  B. HELPER FUNCTIONS (defined at end of script)
%  =========================================================================
% weighted_score(scores, weights) → column vector of weighted totals
% rankings(scores, weights)       → sorted method indices (best first)

%% =========================================================================
%  C. ANALYSIS 1 — ONE-AT-A-TIME (OAT) WEIGHT PERTURBATION
%  =========================================================================
fprintf('\n%s\n', repmat('=',1,70));
fprintf('  ANALYSIS 1 — ONE-AT-A-TIME WEIGHT PERTURBATION (±0.05)\n');
fprintf('%s\n', repmat('=',1,70));

fig_num = 1;
for study = {IBD, NEO}
    S = study{1};
    [nM, nC] = size(S.scores);
    delta     = 0.05;
    base_wt   = weighted_score(S.scores, S.w_base);
    [~, base_ord] = sort(base_wt, 'descend');

    fprintf('\n── %s (baseline weights) ──\n', S.label);
    for m = 1:nM
        fprintf('  %-30s  %.3f\n', S.methods{m}, base_wt(m));
    end

    % Build OAT table: rows = criteria × {+,-}, cols = methods
    perturbations = [+delta; -delta];
    rank_changes  = strings(nC*2, nM);
    gaps          = zeros(nC*2, 1);
    row_labels    = strings(nC*2, 1);

    row = 0;
    for c = 1:nC
        for d = 1:2
            row = row + 1;
            w_new = perturb_weights(S.w_base, c, perturbations(d));
            wt_new = weighted_score(S.scores, w_new);
            [sorted_wt, ord] = sort(wt_new, 'descend');
            gaps(row) = sorted_wt(1) - sorted_wt(2);
            row_labels(row) = sprintf('%s %+.2f', S.criteria{c}, perturbations(d));
            changed = (ord(1) ~= base_ord(1));
            for m = 1:nM
                rank_changes(row, find(ord==m)) = num2str(find(ord==m));
            end
            flag = '';
            if changed; flag = '  *** RANK CHANGE ***'; end
            fprintf('  %-28s  Rank 1: %-28s  Gap: %.3f%s\n', ...
                row_labels(row), S.methods{ord(1)}, gaps(row), flag);
        end
    end

    % Figure: OAT rank-1 gap bar chart
    figure(fig_num); fig_num = fig_num + 1;
    bar(gaps, 'FaceColor', [0.25 0.47 0.70]);
    xticks(1:nC*2); xticklabels(row_labels);
    xtickangle(45);
    ylabel('Gap between rank-1 and rank-2 (weighted score)');
    title(sprintf('OAT Sensitivity — %s', S.label), 'FontWeight', 'bold');
    yline(0, 'r--', 'LineWidth', 1.2);
    grid on; box on;
    set(gca, 'FontSize', 9);
end

%% =========================================================================
%  D. ANALYSIS 2 — MONTE CARLO (Dirichlet, uniform on simplex)
%  =========================================================================
fprintf('\n%s\n', repmat('=',1,70));
fprintf('  ANALYSIS 2 — MONTE CARLO SENSITIVITY\n');
fprintf('%s\n', repmat('=',1,70));

N_mc = 100000;  % Number of random weight draws

for study = {IBD, NEO}
    S = study{1};
    [nM, nC] = size(S.scores);

    % Draw N_mc weight vectors from Dirichlet(alpha=1) = uniform on simplex
    % Dirichlet sample: normalise independent Exp(1) draws
    raw   = -log(rand(N_mc, nC));   % Exp(1) samples
    w_mc  = raw ./ sum(raw, 2);     % normalise → Dirichlet(1,...,1)

    win_count   = zeros(nM, 1);
    rank2_count = zeros(nM, 1);
    wt_all      = zeros(N_mc, nM);

    for k = 1:N_mc
        wt = S.scores * w_mc(k,:)';
        wt_all(k,:) = wt';
        [~, ord] = sort(wt, 'descend');
        win_count(ord(1))   = win_count(ord(1))   + 1;
        rank2_count(ord(2)) = rank2_count(ord(2)) + 1;
    end

    p_win   = win_count   / N_mc;
    p_rank2 = rank2_count / N_mc;

    fprintf('\n── %s (N=%d) ──\n', S.label, N_mc);
    fprintf('  %-32s  %10s  %10s\n', 'Method', 'P(rank 1)', 'P(rank 2)');
    [~, ord] = sort(p_win, 'descend');
    for m = ord'
        fprintf('  %-32s  %9.1f%%  %9.1f%%\n', ...
            S.methods{m}, p_win(m)*100, p_rank2(m)*100);
    end
    winner_idx = find(strcmp(S.methods, S.winner));
    fprintf('\n  → %s holds rank 1 in %.1f%% of all random weight draws.\n', ...
        S.winner, p_win(winner_idx)*100);

    % Figure: P(rank 1) bar chart
    figure(fig_num); fig_num = fig_num + 1;
    [p_sorted, sort_ord] = sort(p_win, 'descend');
    labels_sorted = S.methods(sort_ord);
    b = bar(p_sorted * 100, 'FaceColor', 'flat');
    colors = repmat([0.80 0.80 0.80], nM, 1);
    colors(1,:) = [0.18 0.49 0.20];   % winner in green
    b.CData = colors;
    xticks(1:nM); xticklabels(labels_sorted); xtickangle(35);
    ylabel('P(rank 1)  [%]');
    title(sprintf('Monte Carlo Sensitivity — %s\n(N=%d uniform Dirichlet draws)', ...
        S.label, N_mc), 'FontWeight', 'bold');
    ylim([0 100]); grid on; box on;
    set(gca, 'FontSize', 9);
    % sgtitle(sprintf('Monte Carlo: %s', S.label));
end

%% =========================================================================
%  E. ANALYSIS 3 — THRESHOLD ANALYSIS (bidirectional single-criterion sweeps)
%  =========================================================================
% Fix note: original script swept from 0.01 upward regardless of baseline,
% so it detected downward flips (weight shrinking) before upward ones, and
% mislabelled them as "flips at w > X". Corrected to sweep UP and DOWN from
% baseline independently, report both directions, and show margin from baseline.
% =========================================================================
fprintf('\n%s\n', repmat('=',1,70));
fprintf('  ANALYSIS 3 — THRESHOLD ANALYSIS (single-criterion sweeps)\n');
fprintf('%s\n', repmat('=',1,70));

for study = {IBD, NEO}
    S = study{1};
    [nM, nC] = size(S.scores);
    winner_idx = find(strcmp(S.methods, S.winner));

    fprintf('\n── %s ──\n', S.label);
    fprintf('  %-25s  %-6s  %s\n', 'Criterion', 'Base', 'Threshold result');

    % Storage for figure: use upward threshold (most policy-relevant)
    thresh_up_vals = nan(nC, 1);
    thresh_dn_vals = nan(nC, 1);

    for c = 1:nC
        base_val  = S.w_base(c);
        thresh_up = NaN;  loser_up = '';
        thresh_dn = NaN;  loser_dn = '';

        % ── Sweep UPWARD from baseline ────────────────────────────────────
        for wval = (base_val + 0.01) : 0.01 : 0.50
            w_new = perturb_weights(S.w_base, c, wval - base_val);
            wt    = weighted_score(S.scores, w_new);
            [~, ord] = sort(wt, 'descend');
            if ord(1) ~= winner_idx
                thresh_up = wval;
                loser_up  = S.methods{ord(1)};
                break;
            end
        end

        % ── Sweep DOWNWARD from baseline ──────────────────────────────────
        for wval = (base_val - 0.01) : -0.01 : 0.01
            w_new = perturb_weights(S.w_base, c, wval - base_val);
            wt    = weighted_score(S.scores, w_new);
            [~, ord] = sort(wt, 'descend');
            if ord(1) ~= winner_idx
                thresh_dn = wval;
                loser_dn  = S.methods{ord(1)};
                break;
            end
        end

        thresh_up_vals(c) = thresh_up;
        thresh_dn_vals(c) = thresh_dn;

        % ── Console output ────────────────────────────────────────────────
        fprintf('  %-25s  %.2f\n', S.criteria{c}, base_val);
        if isnan(thresh_up)
            fprintf('      ↑ Stable (no flip up to w=0.50)\n');
        else
            fprintf('      ↑ Flips at w > %.2f  (margin +%.2f) → %s\n', ...
                thresh_up, thresh_up - base_val, loser_up);
        end
        if isnan(thresh_dn)
            fprintf('      ↓ Stable (no flip down to w=0.01)\n');
        else
            fprintf('      ↓ Flips at w < %.2f  (margin -%.2f) → %s\n', ...
                thresh_dn, base_val - thresh_dn, loser_dn);
        end
    end

    % ── Figure: margin-based grouped bar chart ────────────────────────────
    % Shows margin from baseline to flip (not absolute weight), so the
    % "safety margin" is immediately readable. Upward margin = blue (positive),
    % downward margin = red (shown as negative). Stable criteria get a
    % hatched/capped bar at the max-tested margin ceiling.
    figure(fig_num); fig_num = fig_num + 1;

    CEIL = 0.50 - max(S.w_base);   % max possible upward margin varies by criterion
    margin_up = nan(nC, 1);
    margin_dn = nan(nC, 1);
    cap_up    = false(nC, 1);
    cap_dn    = false(nC, 1);

    for c = 1:nC
        if ~isnan(thresh_up_vals(c))
            margin_up(c) =  thresh_up_vals(c) - S.w_base(c);
        else
            margin_up(c) =  0.50 - S.w_base(c);   % stable → cap at max
            cap_up(c)    = true;
        end
        if ~isnan(thresh_dn_vals(c))
            margin_dn(c) = -(S.w_base(c) - thresh_dn_vals(c));  % negative
        else
            margin_dn(c) = -(S.w_base(c) - 0.01);               % stable → cap at min
            cap_dn(c)    = true;
        end
    end

    % ── Grouped bar chart: upward margin (blue) | downward margin (red) ──
    % Solid fill  = real flip exists within tested range (annotated with w=X)
    % Faded fill  = stable to limit; marked with a diamond (◆) at bar tip
    % Zero line   = baseline weight (the reference point for all margins)
    bar_data = [margin_up, margin_dn];
    b = bar(bar_data, 'grouped');

    % Per-bar face colours using CData (solid vs faded per stable flag)
    blue_solid = [0.18 0.45 0.72];
    blue_faded = [0.18 0.45 0.72];   % same hue, alpha handles fade
    red_solid  = [0.75 0.18 0.13];
    red_faded  = [0.75 0.18 0.13];

    b(1).FaceColor = 'flat';
    b(2).FaceColor = 'flat';
    cdata_up = zeros(nC, 3);
    cdata_dn = zeros(nC, 3);
    alpha_up = ones(nC, 1);
    alpha_dn = ones(nC, 1);
    for c = 1:nC
        cdata_up(c,:) = blue_solid;
        cdata_dn(c,:) = red_solid;
        if cap_up(c); alpha_up(c) = 0.32; end
        if cap_dn(c); alpha_dn(c) = 0.28; end
    end
    b(1).CData     = cdata_up;
    b(2).CData     = cdata_dn;
    b(1).FaceAlpha = 0.88;   % MATLAB bar only takes scalar alpha; per-bar done via CData lightness
    b(2).FaceAlpha = 0.88;

    % Workaround for per-bar opacity: redraw capped bars in lighter colour
    for c = 1:nC
        if cap_up(c); b(1).CData(c,:) = blue_solid * 0.5 + [0.62 0.62 0.62]; end
        if cap_dn(c); b(2).CData(c,:) = red_solid  * 0.5 + [0.68 0.68 0.68]; end
    end

    hold on;

    % Zero line — the baseline reference
    yline(0, 'k-', 'LineWidth', 1.6, 'HandleVisibility', 'off');

    % Diamond (◆) markers at tip of stable/capped bars
    bw = b(1).BarWidth;   % normalised bar group width
    x_off_up = -bw * 0.27;   % left sub-bar x offset from group centre
    x_off_dn =  bw * 0.27;   % right sub-bar x offset
    for c = 1:nC
        if cap_up(c)
            plot(c + x_off_up, margin_up(c), 'd', ...
                'MarkerSize', 6, 'MarkerFaceColor', blue_solid * 0.6, ...
                'MarkerEdgeColor', 'none', 'HandleVisibility', 'off');
        end
        if cap_dn(c)
            plot(c + x_off_dn, margin_dn(c), 'd', ...
                'MarkerSize', 6, 'MarkerFaceColor', red_solid * 0.6, ...
                'MarkerEdgeColor', 'none', 'HandleVisibility', 'off');
        end
    end

    % Annotate real-flip bars with absolute weight value
    for c = 1:nC
        if ~isnan(thresh_up_vals(c))
            text(c + x_off_up, margin_up(c) + 0.006, ...
                sprintf('w=%.2f', thresh_up_vals(c)), ...
                'FontSize', 11, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', 'Color', blue_solid * 0.9, ...
                'FontWeight', 'bold');
        end
        if ~isnan(thresh_dn_vals(c))
            text(c + x_off_dn, margin_dn(c) - 0.006, ...
                sprintf('w=%.2f', thresh_dn_vals(c)), ...
                'FontSize', 11, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top', 'Color', red_solid * 0.9, ...
                'FontWeight', 'bold');
        end
        % Baseline weight shown in muted text just below zero line
        text(c, 0.003, sprintf('base\n%.2f', S.w_base(c)), ...
            'FontSize', 9, 'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', 'Color', [0.45 0.45 0.45]);
    end

    % Light ±0.10 guide lines for quick margin reading
    yline( 0.10, '--', 'Color', [0.70 0.70 0.70], 'LineWidth', 0.8, ...
        'HandleVisibility', 'off');
    yline(-0.10, '--', 'Color', [0.70 0.70 0.70], 'LineWidth', 0.8, ...
        'HandleVisibility', 'off');
    hold off;

    xticks(1:nC); xticklabels(S.criteria); xtickangle(35);
    ylabel('Margin from baseline weight to rank-1 flip', 'FontSize', 14);

    y_max = max(margin_up) * 1.22;
    y_min = min(margin_dn) * 1.22;
    ylim([y_min, y_max]);

    title(sprintf('Threshold Analysis — %s', S.label), ...
        'FontWeight', 'bold', 'FontSize', 10);
    subtitle('↑ blue = headroom increasing  |  ↓ red = headroom decreasing  |  faded + ◆ = stable to tested limit', ...
        'FontSize', 8, 'Color', [0.35 0.35 0.35]);
    legend({'↑ Upward margin (solid = real flip; faded = stable to 0.50)', ...
            '↓ Downward margin (solid = real flip; faded = stable to 0.01)'}, ...
        'Location', 'best', 'FontSize', 10);
    grid on; box on;
    set(gca, 'FontSize', 11);

    % ── Additional: NEO 2D sweep (Sensitivity vs TRL) ─────────────────────
    if strcmp(S.label, 'Gradiometry Instruments')
        fprintf('\n  NEO 2D sweep: Sensitivity weight vs TRL weight\n');
        fprintf('  (TRL absorbs the compensating weight change)\n');
        fprintf('  %-10s  %-10s  %-28s  %s\n', ...
            'Sens_w', 'TRL_w', 'Rank 1', 'Gap');
        sens_sweep = 0.05:0.05:0.50;
        for si = 1:length(sens_sweep)
            w = S.w_base;
            delta = sens_sweep(si) - w(2);
            w(2)  = sens_sweep(si);
            w(1)  = max(0.02, w(1) - delta);
            w     = w / sum(w);
            wt    = weighted_score(S.scores, w);
            [~, ord] = sort(wt, 'descend');
            gap  = wt(ord(1)) - wt(ord(2));
            flag = '';
            if ord(1) ~= winner_idx; flag = '  ← FLIP'; end
            fprintf('  %-10.2f  %-10.3f  %-28s  %.3f%s\n', ...
                sens_sweep(si), w(1), S.methods{ord(1)}, gap, flag);
        end
    end
end

fprintf('\n%s\n', repmat('=',1,70));
fprintf('  Analysis complete. Figures 1–6 generated.\n');
fprintf('%s\n\n', repmat('=',1,70));

%% =========================================================================
%  LOCAL FUNCTIONS
%  =========================================================================

function wt = weighted_score(scores, weights)
    % weighted_score  Compute weighted total scores for all methods
    %   scores:  [nMethods × nCriteria] matrix of integer scores (1–5)
    %   weights: [1 × nCriteria] weight vector summing to 1
    %   wt:      [nMethods × 1] weighted totals
    wt = scores * weights(:);
end

function w_new = perturb_weights(w_base, crit_idx, delta)
    % perturb_weights  Adjust one criterion weight by delta, redistribute
    %                  proportionally across all other criteria.
    %   w_base:    baseline weight vector
    %   crit_idx:  index of criterion to perturb (1-indexed)
    %   delta:     signed change to apply
    %   w_new:     perturbed weight vector (sums to 1, all >= 0)
    w_new = w_base(:)';
    w_new(crit_idx) = w_new(crit_idx) + delta;
    w_new(crit_idx) = max(0, min(1, w_new(crit_idx)));
    others = setdiff(1:length(w_base), crit_idx);
    total_others = sum(w_new(others));
    if total_others > 1e-12
        w_new(others) = w_new(others) * (1 - w_new(crit_idx)) / total_others;
    end
    % Safety renorm to handle floating point
    w_new = w_new / sum(w_new);
end