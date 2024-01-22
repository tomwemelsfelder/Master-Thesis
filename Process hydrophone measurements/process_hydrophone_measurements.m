close all;

% Select scope data to be plotted
scopeFirst = 76; scopeLast = 118; %Range of scope data to analyse
scopeAll = scopeFirst:1:scopeLast;
scopeExclude = [76:1:82,84,87,89,91,94,96,97:1:106,109:1:132,137,139,140,142:1:145];
scopeSelected = setdiff(scopeAll,scopeExclude);

n = length(scopeSelected);
Q_array = zeros(n,1);
mode_array = string(zeros(n,1));
shunt_array = string(zeros(n,1));

% plot scope data and calculate Q-factor
i = 1;
for  scope = scopeSelected
    [Q_array(i), mode_array(i), shunt_array(i)] = plot_hydrophone_data(scope);
    i = i + 1;
end

% Define the desired order of shunts
desiredShuntOrder = flip({'no damping', 'R', 'inductor simulator', 'RL', 'feedback'});

% Group the data by mode
modes = categorical(mode_array);
uniqueModes = {'counterpulse','single pulse'};  % Get unique modes
nModes = numel(uniqueModes);  % Number of unique modes


%% plot Q-factors in bar chart, ordered by driving waveform
% Set up a color map for the modes
colorMap = ['#0055FF';'#FFFF00']; 

% Create a horizontal bar chart
figure('Position',[0,0,450,300]);

% Initialize variables to keep track of the vertical position and y-axis labels
verticalPosition = 1;
ytickPositions = [];
ytickLabels = {};

for i = 1:nModes
    mode = uniqueModes(i);
    modeIndices = modes == mode;
    Q_mode = Q_array(modeIndices);
    shunts_mode = shunt_array(modeIndices);

    for shunt_name = desiredShuntOrder
        shuntIndex = shunts_mode == shunt_name;
        shunt = shunts_mode(shuntIndex);
        Q = Q_mode(shuntIndex);

        % Plot the horizontal bars for this mode with a unique color and stacked below the previous bars
        barh(verticalPosition + (1:numel(Q)), Q, 'FaceColor', colorMap(i, :)); hold on;
        
        % Update y-axis labels for this mode
        modeLabels = repmat(shunt_name, numel(Q), 1);
        ytickPositions = [ytickPositions, (1:numel(Q)) + verticalPosition];
        ytickLabels = [ytickLabels; modeLabels];
        
        % Update the vertical position for the next item
        verticalPosition = verticalPosition + numel(Q);
    end
    
    verticalPosition = verticalPosition + 1;
    
    if isempty(Q_mode) == 0
        % Add the mode name in bold letters to the chart
        text(-0.05, verticalPosition - 0.25, char(mode), 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
    end   
end

yticks(ytickPositions);
yticklabels(ytickLabels);
ytickangle(0); 
xlabel('Q factor');
title('Overview of damping methods');
fig = gcf;
exportgraphics(fig,'damping_methods_comparison.png','Resolution',300);

hold off;

%%
function [Q, mode, shunt_name] = plot_hydrophone_data(measurementNumber)
    % set custom plot colors
    hydro_blue = "#8888FF";
    filter_red = "#FF1111";


    % get data from mat files
    hydrophone_measurements = matfile('hydrophone_measurements.mat');
    measurement_names = matfile('measurement_names.mat');
    shunt_names = matfile('shunt_names.mat');
    measurementNames = measurement_names.("measurementNames");
    shuntNames = shunt_names.("shuntNames");
    
    % make id based on measurement number
    mode = string(measurementNames.mode(measurementNumber+1));
    shunt_name = shuntNames.name(measurementNames.shunt(measurementNumber+1) + 1);

    % For all measurements a 2mV scale was used on the oscilloscope,
    % except for feedback where it was 1mV.
    scale = 2; 
    if shunt_name == "feedback" 
        scale = 1;
    end

    %Initialize measurement data
    tableName = sprintf('scope%d', measurementNumber);
    scope = hydrophone_measurements.(tableName);
    
    % add zero padding to time signal, set time and frequency axes
    t = scope.xaxis;
    tres = t(2) - t(1);
    m = 1000000; % amount of zero padding
    t = [t; ((t(end)+tres):tres:(t(end)+m*tres))'];
    Vhydro = scale*[scope.VarName2 - mean(scope.VarName2); zeros(m,1)];
    Fs = 1/(t(2)-t(1));
    F_nyquist = Fs/2;
    Fres = Fs/length(t);
    f = -F_nyquist:Fres:(F_nyquist - Fres);
    N = length(f);
    

    %Remove DC component
    Vhydro = Vhydro - mean(Vhydro);


    %Bandpass filter hydrophone data
    Fc_low = 600e3; % Cutoff frequency lowpass (Hz)
    Fc_high = 200e3; % Cutoff frequency highpass (Hz)
    [b,a] = butter(6,Fc_low/F_nyquist,'low');
    [d,c] = butter(5,Fc_high/F_nyquist,'high');
    Vhydro_filt = filter(d,c,filter(b,a,Vhydro));

    % get frequency spectrum of original and filtered hydrophone data
    Yhydro = abs(fftshift(fft(Vhydro)))/(Fs*N);
    Yhydro_filt = abs(fftshift(fft(Vhydro_filt)))/(Fs*N);
   
    % process filtered spectrum to find Q-factor
    frange = 2*Fc_low; % frequency range to consider in calculation
    idx_start = find(f>=0,1,'first');
    idx_end = find(f>frange,1,'first');
    f_start = f(idx_start);
    Y_filt = Yhydro_filt(idx_start:idx_end);
    Y = Yhydro(idx_start:idx_end);
    [~,idx_max] = max(Y_filt);
    Ymax = Y(idx_max);
    Yhalf = Ymax/2;

    idx_half_first = find(Y_filt(1:idx_max)<=Yhalf,1,'last');
    idx_half_last = find(Y_filt(idx_max:end)<=Yhalf,1,'first') + idx_max - 1;
    f_half_first = Fres * idx_half_first - f_start;
    f_half_last = Fres * idx_half_last - f_start;
    B = f_half_last - f_half_first;
    f_max = Fres * idx_max - f_start;
    f_mid = (f_half_last + f_half_first)/2;
    f_selected = f_mid;
    Q = f_selected/B;
    
    f(1)
    f(2)
    % plot amplitude spectrum
    figure('Position',[0,0,600,175]);
    subplot(1,2,1);
    plot(f/1000,Yhydro,'--','Color',hydro_blue); hold on;
    plot(f/1000,Yhydro_filt,'Color',filter_red,'LineWidth',1.5);

    plot(f_half_first/1000,Yhalf,'ob','LineWidth',1.5);
    plot(f_half_last/1000,Yhalf,'ob','LineWidth',1.5);
    plot(f_selected/1000,Ymax,'^','Color','b','LineWidth',1.5)

    xline(f_half_first/1000,'--','LineWidth',1.5);
    xline(f_half_last/1000,'--','LineWidth',1.5);
    yline(Ymax,'--');
    xline(f_mid/1000,'--');

    xlim([0,1e3]); 
    ylim([0,max(Yhydro(idx_start:idx_end))*1.1])
    xlabel('frequency [$kHz$]','interpreter','latex');
    ylabel('Amplitude [$V/\sqrt{Hz}$]','interpreter','latex')
    %title('Amplitude spectrum')
    %xticklabels('');
    grid on;
    

    % Plot hydrophone signal in time domain
    subplot(1,2,2)
    plot(t*1e6,Vhydro*1e3,'--','LineWidth',0.1,'Color',hydro_blue); hold on;
    plot(t*1e6,Vhydro_filt*1e3,'LineWidth',1.5,'Color',filter_red);

    xlim([t(1)*1e6,t(1)*1e6+50])
    %ylim([-10,10]);

    legend({'Raw','Filtered'},'Position',[0.77,0.24,0.1,0.1],'Box','off')
    xlabel('time [$\mu s$]','interpreter','latex'); 
    ylabel('V [$mV$]','interpreter','latex');
    %title('Hydrophone data');
    %xticklabels('');
    grid on;

    % Add supertitle
    plot_title = sprintf("%s, %s, Q = %.2f",mode,shunt_name,Q);
    %sgtitle(plot_title);
    
    % Save figure
    figure_name = sprintf("%s_%s.png",mode,shunt_name);
    fig = gcf;
    exportgraphics(fig,figure_name,'Resolution',300);

end

