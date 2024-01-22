close all;

%% Fit and plot primary resonance frequency of trace for 2x2mm transducer
figure()
trace = 3;
fit_and_plot_measurements(measurements23_04_05_2x2,trace,0.4e6,1.1e6,1,1,0);
title('Impedance measurement 2MHz 2x2mm transducers');
legend('Measurement','Curve fit');

%% Fit and plot primary and secondary resonance frequency of trace for 4x4mm transducer
figure('Position', [0, 0, 500, 300])
trace = 4;
[Z4x4_1,line_handle] = fit_and_plot_measurements(measurements23_04_05_4x4,trace,0.2e6,0.59e6,8,1,0);
line_handle.LineStyle = "--";
line_handle.LineWidth = 1;
title('Curve fitting for a 4x4mm PZT transducer'); hold on;

[Z4x4_2,line_handle] = fit_and_plot_measurements(measurements23_04_05_4x4,trace,0.95e6,1.2e6,1,0,0);
line_handle.LineStyle = ':';
line_handle.LineWidth = 1.5;
legend('measurement','curve fit 1','curve fit 2');
ylim([4e1,6e4])
f = gcf;
exportgraphics(f,'curve_fit_secondary_resonance.png','Resolution',300);


%% Fit trace in range [fmin, fmax] and plot the result
function [Co_fit,Cm_fit,Lm_fit,Rm_fit,Zpzt,line_handle] = curve_fit_and_plot(trace, fmin, fmax, scaling_factor, plot_z, plot_range)
    %% plot measured Z and optionally indicate range [fmin:fmax] in which to find the resonant frequency and anti-resonant frequency. 
    if plot_z == 1
        plot_Z(trace,fmin,fmax,plot_range);
    end
    hold on;

    %% find equivalent BVD-model parameters based on data in range [fmin, fmax]
    [Co, Cm, Lm, Rm] = get_equivalent_parameters(trace,fmin,fmax);
    
    %% Define range for curve fitting
    f = trace.f;
    s = 1i*2*pi*f;   
    start_idx = find(f>=fmin,1,'first');
    stop_idx = find(f>=fmax,1,'first');
    f_fit = f(start_idx:stop_idx);
    s_fit = 1i*2*pi*f_fit;

    %% scale the equivalent parameters. Can be set to something other than 1 in case of a bad fit.
    Co = Co/scaling_factor;
    Cm=Cm/scaling_factor;
    Lm = Lm*scaling_factor;
    
    %% create model with parameters defined as follows:
    % Cm_fit = km * Cm
    % Co_fit = ko * Co
    % km = params(1)
    % ko = params(2)
    % Lm = params(3)
    % Rm = params(4)
    model = @(params,f)abs((s_fit.^2*params(1)*Cm*params(3) + s_fit*params(4)*params(1)*Cm + 1)./...
        (s_fit.^3*params(2)*Co*params(1)*Cm*params(3) + s_fit.^2*params(2)*Co*params(1)*Cm*params(4) + s_fit*(params(2)*Co+params(1)*Cm)));
    params_initial = [1, 1, Lm, Rm];

    %% Do least-squares curve-fitting
    params = lsqcurvefit(model,params_initial,f,trace.Z(start_idx:stop_idx)) ;

    %% Retrieve fitted parameters
    Cm_fit = params(1)*Cm;
    Co_fit = params(2)*Co;
    Lm_fit = params(3);
    Rm_fit = params(4);

    fprintf('Co = %f pF\n',Co_fit*1e12);
    fprintf('Cm = %f pF\n',Cm_fit*1e12);
    fprintf('Lm = %f mH\n',Lm_fit*1e3);
    fprintf('Rm = %f Ohm\n',Rm_fit);
    
    %% plot fitted transfer function
    Zpzt = abs((s.^2*Cm_fit*Lm_fit + s*Rm_fit*Cm_fit + 1)./...
        (s.^3*Co_fit*Cm_fit*Lm_fit + s.^2*Co_fit*Cm_fit*Rm_fit + s*(Co_fit+Cm_fit)));

    line_handle = semilogy(f/1e6,Zpzt);

end

%% Plot trace data. Optionally show range over which curve should be fitted
function [] = plot_Z(trace,fmin,fmax,plot_lines)
    f = trace.f;
    Z = trace.Z;
    
    semilogy(f/1e6, Z);hold on;
    ylabel('Z [\Omega]');
    xlabel('frequency [MHz]');
    
    if plot_lines ~= 0
        xline(fmin/1e6,'--');
        xline(fmax/1e6,'--');
    end
end

%% Calculate equivalent BVD-model parameters for specified trace data in range [fmin, fmax]
function [Co, Cm, Lm, Rm, fr, far] = get_equivalent_parameters(trace, fmin, fmax)
    %% get frequency range
    f = trace.f;
    start_idx = find(f>=fmin,1,'first');
    stop_idx = find(f>=fmax,1,'first');
    
    %% extract measurement data
    phase = trace.phase;
    Z = trace.Z;
    ReZ = Z.*cosd(phase);
    ImZ = Z.*sind(phase);


    
    
    %% crop data to the specified range [fmin, fmax]
    f = f(start_idx:stop_idx);
    ReZ = ReZ(start_idx:stop_idx);
    ImZ = ImZ(start_idx:stop_idx);
    Z = Z(start_idx:stop_idx);
  
    %% find resonat (r) and anti-resonant (ar) frequency and impedance
    [Zr,r_idx] = min(Z);
    [~, ar_idx] = max(Z);
    
    ImZr = ImZ(r_idx);
    ReZr = ReZ(r_idx);
    fr = f(r_idx);
    far = f(ar_idx);
    
    %% calcualte initial estimates of equivalent parameters
    Co = abs(ImZr/(2*pi*fr*Zr.^2));
    Cm = Co * ((far/fr)^2 - 1);
    Lm = 1/((2*pi*fr)^2 * Cm);
    Rm = (Zr^2)/ReZr;
end

%% Curve fit and plot data for either all traces or a single specified trace within a measurement set
function [Zpzt,line_handle] = fit_and_plot_measurements(measurements,measurement_number,fmin,fmax,scaling_factor,plot_z,plot_range)
    % amount of datapoints
    n = size(measurements,1);
    
    %% allow for plotting of multiple curves at once. if measurement_number = 0: plot all curves in the measurement cell
    if measurement_number == 0
        measurement_number = 1:1:n;
    end

    fr_fit = zeros(n,1);
    for i = measurement_number
        [Co,Cm,Lm,Rm,Zpzt,line_handle] = curve_fit_and_plot(measurements{i,1},fmin,fmax,scaling_factor,plot_z,plot_range);
        fr_fit(i) = 1/(2*pi*sqrt(Cm*Lm));
    end
end
