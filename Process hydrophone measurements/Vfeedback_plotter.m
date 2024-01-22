close all;

Fc_low = 1000e3; % Cutoff frequency lowpass (Hz)
Fc_high = 200e3; % Cutoff frequency highpass (Hz)
F_nyquist = 1/(2*(SP.xaxis(2)-SP.xaxis(1)));
[b,a] = butter(6,Fc_low/F_nyquist,'low');
[d,c] = butter(5,Fc_high/F_nyquist,'high');

figure(); 
subplot(2,1,1)
yyaxis left;
plot(Vfb_SP.xaxis, Vfb_SP.VarName2); hold on;
Vfb_filt = filter(d,c,filter(b,a,Vfb_SP.VarName2));
yyaxis right;
plot(Vfb_SP.xaxis, Vfb_filt)
xlim([-1e-5, 3e-5])

subplot(2,1,2) 
yyaxis left;
plot(SP.xaxis - 2.15e-6,SP.VarName2);
xlim([-1e-5, 3e-5])
yyaxis right;
Vhydro_filt = filter(d,c,filter(b,a,SP.VarName2 - mean(SP.VarName2)));
hold on;
plot(SP.xaxis - 5e-6,Vhydro_filt)