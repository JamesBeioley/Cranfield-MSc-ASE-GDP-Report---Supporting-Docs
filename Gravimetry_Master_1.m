%% =========================================================================
%% Gradiometry_Core_1.m
%% =========================================================================
% NEO Gravity Gradiometry Core — field model, instrument database, and
% detectability products
%
% Purpose
%   Define the canonical spherical-asteroid gravity gradient model, compute
%   field strength over parametric grids of asteroid diameter and surface
%   offset, and evaluate signal-to-noise and required integration time for
%   a set of candidate gradiometer instruments.
%
% Assumptions
%   - Asteroid modelled as a uniform-density sphere.  The exterior gravity
%     field is identical to that of a point mass at the centre.
%   - Gravity gradient is the radial component of the gradient tensor:
%         Gamma_rr = 2*G*M / r^3
%     This is the strongest diagonal component and the one most directly
%     measured by a single-axis or differential-mode gradiometer.
%   - Instrument noise spectral density is assumed white (flat) over the
%     measurement bandwidth.  SNR improves as sqrt(T) with integration
%     time T — the standard radiometer-type integration.
%   - No attitude noise, orbital dynamics, or thermal drift are included.
%     This is a first-order detectability model.
%
% Outputs
%   NEO.cfg     — configuration struct (all inputs and grid definitions)
%   NEO.const   — physical constants
%   NEO.instr   — instrument database (struct array)
%   NEO.point   — 1D field quantities at the reference altitude
%   NEO.grid    — 2D field quantities over (diameter, surface offset)
%   NEO.detect  — SNR array and required integration time arrays
%
% Recommended run order
%   1) Gradiometry_Core_1.m            <-- this script
%   2) Gradiometry_Plots_2.m
%   3) Gradiometry_Report_Summary_3.m
%
% Key references
%   GOCE performance: Rummel et al. (2011), J. Geodesy 85:777
%   SGG/SQUID concepts: Griggs et al. (2017), Exp. Astron. 43:175
%   Quantum gradiometry: Trimeche et al. (2019), Class. Quantum Grav. 36
% =========================================================================

clc;

%% =========================================================================
%% A) PHYSICAL CONSTANTS
%% =========================================================================
G      = 6.6743e-11;       % gravitational constant [m^3 kg^-1 s^-2]
EOTVOS = 1e-9;             % 1 Eotvos [s^-2]

%% =========================================================================
%% B) INSTRUMENT DATABASE
%% =========================================================================
% Noise spectral density n_E [E/sqrt(Hz)] for each candidate gradiometer.
% Values represent published in-orbit performance, demonstrated laboratory
% sensitivity, or projected flight-grade targets as indicated.

instr = struct([]);

instr(1).name = "GOCE (in-orbit)";
instr(1).nE   = 0.005;                  % Rummel et al. (2011)

instr(2).name = "SGG/SQUID (lab)";
instr(2).nE   = 0.00014;                % Griggs et al. (2017)

instr(3).name = "SGG/SQUID (flight-grade)";
instr(3).nE   = 2e-5;                   % projected

instr(4).name = "QGGPf/CARIOQA (lab)";
instr(4).nE   = 0.1;                    % Trimeche et al. (2019)

instr(5).name = "QGGPf/CARIOQA (flight-grade)";
instr(5).nE   = 1e-5;                   % projected

%% =========================================================================
%% C) PARAMETER GRIDS AND CONFIGURATION
%% =========================================================================
cfg = struct();

% Asteroid diameter sweep [m]
cfg.D_m = logspace(1, log10(5000), 200);

% Bulk density [kg/m^3]
cfg.rho_kgm3 = 2500;

% Surface offset sweep [km]
cfg.h_km = logspace(-2, 6, 250);

% Integration time sweep [s]
cfg.T_list_s = logspace(0, 6, 250);

% Detection threshold
cfg.SNR_target = 5;

% Reference altitude for 1D products
cfg.h0_km = 10;

% Shared detectability settings (used by plots and summary)
cfg.T_floor_s = 1;
cfg.SNR_floor = 5;

% GOCE contour integration times (reused across multiple plots)
cfg.T_GOCE_list_s = [1, 60, 3600, 86400, 604800, 2628000];
cfg.T_GOCE_labels = ["1 s", "1 min", "1 hour", "1 day", "1 week", "1 month"];

%% =========================================================================
%% D) INPUT VALIDATION
%% =========================================================================
assert(cfg.rho_kgm3 > 0,   'Density must be positive.');
assert(cfg.h0_km > 0,       'Reference altitude must be positive.');
assert(cfg.SNR_target > 0,  'SNR target must be positive.');

%% =========================================================================
%% E) CORE FIELD CALCULATIONS
%% =========================================================================
% 1D: field quantities vs diameter at the reference altitude
out_1D = neo_fields_1D(cfg.D_m, cfg.rho_kgm3, cfg.h0_km, G, EOTVOS);

% 2D: field quantities over the full (diameter, surface offset) grid
out_2D = neo_fields_2D(cfg.D_m, cfg.rho_kgm3, cfg.h_km, G, EOTVOS);

%% =========================================================================
%% F) DETECTABILITY PRODUCTS
%% =========================================================================
% SNR array: dimensions (instrument, integration time, diameter)
Ni = numel(instr);
Nt = numel(cfg.T_list_s);
Nd = numel(cfg.D_m);

SNR = zeros(Ni, Nt, Nd);
for k = 1:Ni
    % Vectorise over integration time using outer product
    % gradE is [1 x Nd], sqrt(T) is [Nt x 1] => SNR_k is [Nt x Nd]
    SNR(k,:,:) = (sqrt(cfg.T_list_s(:)) * out_1D.gradE) ./ instr(k).nE;
end

% Required integration time to reach target SNR: T = (SNR_target * nE / Gamma)^2
T_req_s  = zeros(Ni, Nd);
T_req_hr = zeros(Ni, Nd);
for k = 1:Ni
    T_req_s(k,:)  = ((cfg.SNR_target * instr(k).nE) ./ out_1D.gradE).^2;
    T_req_hr(k,:) = T_req_s(k,:) / 3600;
end

%% =========================================================================
%% G) PACKAGE OUTPUTS
%% =========================================================================
NEO = struct();

NEO.cfg   = cfg;
NEO.const = struct('G', G, 'EOTVOS', EOTVOS);
NEO.instr = instr;

NEO.point = out_1D;
NEO.grid  = out_2D;

NEO.detect.SNR      = SNR;
NEO.detect.T_req_s  = T_req_s;
NEO.detect.T_req_hr = T_req_hr;

%% =========================================================================
%% H) LEGACY FLAT EXPORTS
%% =========================================================================
% Retained for backward compatibility with older scripts.

D_m        = cfg.D_m;
rho        = cfg.rho_kgm3;
h_km       = cfg.h_km;
T_list     = cfg.T_list_s;
SNR_target = cfg.SNR_target;
h0         = cfg.h0_km;
T_floor    = cfg.T_floor_s;
SNR_floor  = cfg.SNR_floor;

% Legacy aliases for the field output structs
out  = out_1D;
out2 = out_2D;

%% =========================================================================
%% LOCAL FUNCTIONS
%% =========================================================================

function out = neo_fields_1D(D_m, rho, h_km, G, EOTVOS)
% Compute gravity and gravity-gradient fields vs asteroid diameter at a
% fixed surface offset.
%
%   D_m    — asteroid diameter vector [m]
%   rho    — bulk density [kg/m^3]
%   h_km   — surface offset [km]
%   G      — gravitational constant [m^3 kg^-1 s^-2]
%   EOTVOS — Eotvos unit [s^-2]

R_m  = D_m / 2;                             % radius [m]
M_kg = (4/3) * pi .* R_m.^3 .* rho;         % mass [kg]
r_m  = R_m + h_km * 1000;                   % centre distance [m]

g_ms2   = G .* M_kg ./ r_m.^2;              % gravitational acceleration [m/s^2]
grad_s2 = 2 .* g_ms2 ./ r_m;               % radial gravity gradient [s^-2]
gradE   = grad_s2 ./ EOTVOS;               % gravity gradient [E]

out.R_m     = R_m;
out.M_kg    = M_kg;
out.r_km    = r_m / 1000;
out.r_m     = r_m;
out.g_ms2   = g_ms2;
out.g_uGal  = g_ms2 * 1e8;
out.grad_s2 = grad_s2;
out.gradE   = gradE;
end

function out = neo_fields_2D(D_m, rho, h_km, G, EOTVOS)
% Compute gravity and gravity-gradient fields over the full (diameter,
% surface offset) grid.
%
%   D_m    — asteroid diameter vector [m]
%   rho    — bulk density [kg/m^3]
%   h_km   — surface offset vector [km]
%   G      — gravitational constant [m^3 kg^-1 s^-2]
%   EOTVOS — Eotvos unit [s^-2]

[DD, HH] = meshgrid(D_m, h_km);

R_m  = DD / 2;                              % [m]
M_kg = (4/3) * pi .* R_m.^3 .* rho;         % [kg]
r_m  = R_m + HH * 1000;                    % centre distance [m]

g_ms2   = G .* M_kg ./ r_m.^2;
grad_s2 = 2 .* g_ms2 ./ r_m;
gradE   = grad_s2 ./ EOTVOS;

out.DD      = DD;
out.HH_km   = HH;
out.R_m     = R_m;
out.M_kg    = M_kg;
out.r_m     = r_m;
out.g_ms2   = g_ms2;
out.g_uGal  = g_ms2 * 1e8;
out.grad_s2 = grad_s2;
out.gradE   = gradE;
end