close all;

%% Load the BVD-model equivalent parameters for a transducer
transducer = params4x4_1; 
Co = transducer.Co(1);
Cm = transducer.Cm(1);
Lm = transducer.Lm(1);
Rm = transducer.Rm(1);

%Corresponding transfer function
Hpzt = tf([Cm,0],[Lm*Cm,Rm*Cm,1]);

%% Initial estimates for shunt components Ra and La
Ra_init = 2*sqrt(Cm*Lm/(Co*(4*Co+Cm)));
La_init = Ra_init*sqrt(Cm*Lm);

%% Calculate Ra for R-only damping

% Sweep around the initial estimate for Ra and calculate Q-factor for each
% value
Ra_sweep = logspace(log10(Ra_init)-1,log10(Ra_init)+0.5,100);
Qr = zeros(size(Ra_sweep));
fr = zeros(size(Ra_sweep));
i = 1;
for Ra = Ra_sweep
    Hr_sweep = tf([Cm,0],[Ra*Co*Cm*Lm,Cm*Lm,Ra*(Co+Cm),1]);
    [gpeak, wpeak] = getPeakGain(Hr_sweep);
    w3db = getGainCrossover(Hr_sweep,gpeak/2);
    Qr(i) = wpeak/(w3db(2)-w3db(1));
    fr(i) = wpeak;
    i = i + 1;
end

% Plot the Ra-Q curve
figure('Position', [0, 0, 300, 250]);
plot(Ra_sweep/1000,Qr,'b');
xlabel('R_a [k\Omega]');
ylabel('Q factor');
title('Effect of R_a on Q factor');
% The optimal Ra is where the Q-factor is at its minimum
[Qr_min,idx] = min(Qr);
Wr = fr(idx); % center frequency for R-damping
Ra = Ra_sweep(idx);
fprintf('Ra = %f Ohm \n',Ra);
hold on; plot(Ra/1000,Qr_min,'xb');
ylim([3, 15])
f = gcf;
exportgraphics(f,'Ra-Q.png','Resolution',300)

%% Calculate La for RL-damping
% sweep around the initial estimate for La and calculate the Q-factor for
% each value
style = ["-","--",":","-."];
La_sweep = 0:La_init/50:La_init*1.8;
RaL_sweep = Ra*0.75:Ra*0.5:Ra*2.25; 
legend_text = strings(2*length(RaL_sweep),1);
Qrl = zeros(length(La_sweep),length(RaL_sweep));
% Plot La-Q curve
fig = figure('Position', [0, 0, 300, 250]);
axes(fig,'Position',[0.15,0.175,0.8,0.7])
i = 1; j = 1;
Hrl_sweep = tf(zeros(1,1,length(La_sweep),length(RaL_sweep)));
for RaL = RaL_sweep
    for La = La_sweep
        Hrl_sweep(:,:,i,j) = tf([Cm,0],[La*Co*Cm*Lm, RaL*Co*Cm*Lm, Cm*Lm+La*(Co+Cm), RaL*(Co+Cm),1]);
        [gpeak, wpeak] = getPeakGain(Hrl_sweep(:,:,i,j));
        w3db = getGainCrossover(Hrl_sweep(:,:,i,j),gpeak/2);
        Qrl(i,j) = wpeak/(w3db(end)-w3db(end-1));  
        i = i + 1;
    end
    plot(La_sweep*10^6,Qrl(:,j),'b','LineStyle',style(j)); hold on;
    % optimal La is where Q-factor is at its minimum
    [~,idx] = min(Qrl(:,j)); 
    La = La_sweep(idx);
    fprintf('La = %f uH \n',La*1e6);
    hold on; plot(La*10^6,Qrl(idx,j),'bx');
    legend_text(2*j-1) = sprintf("Ra = %.1fkOhm",RaL*1e-3);
    legend_text(2*j) = '';
    j = j + 1;
    i = 1;
end

xlabel('L_a [\muH]');
ylabel('Q factor');
title('Effect of L_a on Q factor');
legend(legend_text,'Location','northwest');
exportgraphics(fig,'La-Q_RL.png','Resolution',300)

%% La comparison graph
figure('Position', [0, 0, 500, 400]);
rl_sweep_idx = [1,32,91];
rl_sweep_style = [":","-","-."];
legend_text = strings(length(rl_sweep_idx),1);
for i = 1:1:length(rl_sweep_idx)
    idx = rl_sweep_idx(i);
    style = rl_sweep_style(i);
    h = bodeplot(Hrl_sweep(:,:,idx),style); hold on;
    setoptions(h,'FreqUnits','Hz','PhaseVisible','off');
    legend_text(i) = sprintf("La=%.0f uH",La_sweep(idx)*1e6);
end
fr = 1/(2*pi*sqrt(Cm*Lm));
xlim([fr/3,fr*3]);
title('Comparison La impact on RL-damping circuit')
legend(legend_text,'Location', 'southwest');
f = gcf;
exportgraphics(f,'La_comparison.png','Resolution',300)


%% Calculate Ra for RL-damping
% sweep over the same values as for R-damping
Qr = zeros(size(Ra_sweep));
grl = zeros(size(Ra_sweep));
wrl = zeros(size(Ra_sweep));
i = 1;

% calculate the peak gain for each value of Ra
Hrl_sweep = tf(zeros(1,1,length(Ra_sweep)));
for RaL = Ra_sweep    
    Hrl_sweep(:,:,i) = tf([Cm,0],[La*Co*Cm*Lm, RaL*Co*Cm*Lm, Cm*Lm+La*(Co+Cm), RaL*(Co+Cm),1]);
    [gpeak, wpeak] = getPeakGain(Hrl_sweep(:,:,i));
    grl(i) = gpeak;
    wrl(i) = wpeak;
    i = i + 1;
end

% plot the Ra-peak gain curve
fig = figure('Position', [0, 0, 325, 300]);
axes(fig,'Position',[0.15,0.175,0.8,0.8])
plot(Ra_sweep/1000,20*log10(grl),'b');
xlabel('R_a [k\Omega]');
ylabel('Peak gain (dB)');
%title('Effect of R_a on peak gain frequency for RL-damping');
% find the point where the peak gain frequency starts to exceed that of the R-damping circuit. 
% Around this point the damping is optimal.
minimum = min(wrl);
idx = find(wrl>Wr,1,'first');
RaL = Ra_sweep(idx);
hold on; plot(RaL/1000,20*log10(grl(idx)),'xb');
fprintf('RaL = %f Ohm \n',RaL);
exportgraphics(fig,'Ra_peak_gain.png','Resolution',300)


%% RaL comparison graph
fig = figure('Position', [0, 0, 325, 300]);
axes(fig,'Position',[0.15,0.175,0.8,0.8])
rl_sweep_idx = [5,40,55,80];
rl_sweep_style = [":","--","-","-."];
legend_text = strings(length(rl_sweep_idx),1);
for i = 1:1:length(rl_sweep_idx)
    idx = rl_sweep_idx(i);
    style = rl_sweep_style(i);    
    h = bodeplot(Hrl_sweep(:,:,idx),style); hold on;
    setoptions(h,'FreqUnits','Hz','PhaseVisible','off');
    legend_text(i) = sprintf("Ra=%.1f kOhm",Ra_sweep(idx)*1e-3);
end

fr = 1/(2*pi*sqrt(Cm*Lm));
xlim([fr/3,fr*3]);
%title('Comparison Ra impact in RL-damping circuit')
legend(legend_text,'Location', 'southwest');
title('')
exportgraphics(fig,'RaL_comparison.png','Resolution',300)


%% Compare the transfer functions for the undamped, R-damped and RL-damped transducer
Hpzt_r = tf([Cm,0],[Ra*Co*Cm*Lm,Cm*Lm,Ra*(Co+Cm),1]);
Hpzt_rl = tf([Cm,0],[La*Co*Cm*Lm, RaL*Co*Cm*Lm, Cm*Lm+La*(Co+Cm), RaL*(Co+Cm),1]);

fig = figure('Position', [0, 0, 440, 350]);
axes(fig,'Position',[0.15,0.175,0.65,0.7])
h = bodeplot(Hpzt,":b"); hold on;
bodeplot(Hpzt_r,"b--");
bodeplot(Hpzt_rl,"b");
setoptions(h,'FreqUnits','Hz','PhaseVisible','off');
title('Comparison R-damping, RL-damping and no damping')
xlim([fr/3,fr*3]);
legend({'No damping','R-damping','RL-damping'},'Position', [0.28,0.67,0.1,0.1]);
exportgraphics(fig,'R_RL_no-damping.png','Resolution',300)
fprintf('Q pzt = %f \n', get_Q(Hpzt));
fprintf('Q rdamp = %f \n', get_Q(Hpzt_r));
fprintf('Q rldamp = %f \n', get_Q(Hpzt_rl));


%% Compare damping with new values compared to initial values

Hpzt_r_init = tf([Cm,0],[Ra_init*Co*Cm*Lm,Cm*Lm,Ra_init*(Co+Cm),1]);
Hpzt_rl_init = tf([Cm,0],[La_init*Co*Cm*Lm, Ra_init*Co*Cm*Lm, Cm*Lm+La_init*(Co+Cm), Ra_init*(Co+Cm),1]);

function Q = get_Q(transfer_function) 
    [gpeak, wpeak] = getPeakGain(transfer_function);
    w3db = getGainCrossover(transfer_function,gpeak/2);
    Q = wpeak/(w3db(end)-w3db(end-1)); 
end