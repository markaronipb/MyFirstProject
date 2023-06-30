%thickness gauging using the wand
%Comment added!!!
clear scp
clear gen

clear all;
close all;
clc

%#############################################################                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             #############
%-------------------------global parameters-------------------------------
%##########################################################################

sens = [0.8]; %can be 0.2,0.4,0.8,2,4,8,20,40,80
sample_freq = 0.25e6;
pts = 2^14; 
resolution=12;%scope bit depth

centre_freq = 50e3;
cycles = 5;
stretch_factor=1;
sig_amp=12;

vel=6300;

meas_delay=0.1;
iterations_no=100; %how many loops to run
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%connect Handyscope
%run the code to load the library
import LibTiePie.Const.*
import LibTiePie.Enum.*

if ~exist('LibTiePie', 'var')
    % Open LibTiePie:
    LibTiePie = LibTiePie.Library;
end

% Search for devices:
LibTiePie.DeviceList.update();

% Oopen an oscilloscope with and a generator in the same device:
item = LibTiePie.DeviceList.getItemByIndex(0);
scp = item.openOscilloscope();
gen = item.openGenerator();
clear item

scp.MeasureMode = MM.BLOCK;
%scp.MeasureMode = 2;
scp.RecordLength = pts;
scp.SampleFrequency = sample_freq;
pretrig=0;
scp.PreSampleRatio = pretrig;

for ch = scp.Channels
    ch.Enabled = true;
    ch.Range = sens; % 8 V
    ch.Coupling = CK.ACV; % DC Volt
    %ch.Coupling = 2; % DC Volt
    clear ch;
end
scp.Channels(2).Enabled = false;

scp.Resolution = resolution;
scp.TriggerTimeOut = 1;

%----------------------Chirp signal generator constants----------------------
%specify max time based on constants at top
max_time=pts./sample_freq;

%function generator
gen.OutputOn = false;
gen.SignalType = ST.ARBITRARY;
gen.FrequencyMode = FM.SAMPLEFREQUENCY;
gen.Frequency = sample_freq;
gen.Amplitude =sig_amp;
gen.Offset = 0;

%create the chirp signal
time_step=1./sample_freq;
[time,chirp_signal,freq,in_freq_spec,fft_pts]=fn_create_input_signal(pts,centre_freq,time_step,cycles,'hanning',1/centre_freq*cycles*2);
centre_time = 1/centre_freq*cycles*2;

%gen.setData(real(chirp_signal));
gen.OutputOn = true;

% Disable all channel trigger sources:
for ch = scp.Channels
    ch.Trigger.Enabled = false;
    clear ch;
end

% Locate trigger input:
triggerInput = scp.getTriggerInputById(TIID.GENERATOR_NEW_PERIOD); % or TIID.GENERATOR_START or TIID.GENERATOR_STOP or TIID.GENERATOR_NEW_PERIOD
% Enable trigger input:
triggerInput.Enabled = true;
gen.OutputOn = true;

count=1;
gen.start();

while 1%count<= iterations_no
    
    scp.start();
    
    while ~scp.IsDataReady
        pause(10e-3);
    end
    % Get data:
    tmp_dat = scp.getData();
    data=tmp_dat(:,1);
    norm_data=hilbert(data)./max(abs(hilbert(data)));
    %norm_data=data;
    amps(count)=max(abs(norm_data));
    %first loop to get the time axis and the vertical axis parameters
    if count == 1
        t = ([1:pts]' - (pts - round((1-pretrig)*pts))) / sample_freq;
        
    end;
    
    %plot data from whatever channels are recorded
    if ~isempty(data)
                       
        if count==1
            figure
            subplot(2,1,1)
            fighan1=plot(t-centre_time,real(norm_data));
             hold on
             fighan2=plot(t-centre_time,abs(norm_data),'r');
            ylim([-1 1])
            xlabel('time / sec')
            ylabel('Amplitude / arb. units')
            title('Live received signals')
            grid
             subplot(2,1,2)
             fighan3=plot(amps, 'r.');
             plothan=gca;
             ylim([0 1.1])
             xlim([0 iterations_no])
             ylabel('Amplitude')
             xlabel('Measurement no.')
             title('Sig amplitude')
             grid
                        
        else
            set(fighan1,'YData',real(norm_data));
             set(fighan2,'YData',abs(norm_data));
             set(fighan3,'YData',amps)
            drawnow
        end
    end;
    count=count+1;
    pause(meas_delay)
 end;

clear scp
clear gen