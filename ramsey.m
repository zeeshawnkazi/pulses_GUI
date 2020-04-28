function ramsey(handles, varargin)
    cla(handles.axes1)
    cla(handles.axes2)
    
    bath_rf_power = getN(handles.bath_power);
    if bath_rf_power > -30
        bath_sweep =1;
    else
        bath_sweep =0;
    end
    % flags
    normalize = 0;
    data_from_middle = 0;
    
    %% file names and plot labels     
    dateandtime = get_dateandtime;
    x_label = 'free evolution time (ns)';
    y_label = 'normalized pl';
    if ~isempty(varargin)
        mat_file_name = varargin{1};
    elseif bath_sweep
        bath_rf_start                   = getN(handles.bath_rf_start);        % frequency in GHz
        bath_rf_end                     = getN(handles.bath_rf_end);          % frequency in GHz
        mat_file_name = ['ramsey_bath_sweep_' num2str(bath_rf_start) 'to' num2str(bath_rf_end) 'MHz.mat'];
    else
        mat_file_name = 'ramsey_sweep.mat';
    end
    
    final_fig_name= 'ramsey_sweep.fig';
    data_folder = 'E:\Dropbox\Projects\magPI\pulses_GUI\ramsey_sweeps';
    log_folder  = 'E:\Dropbox\Projects\magPI\pulses_GUI\ramsey_log'; % averaged sweep figure is logged here
    
    
    %% global constants
    % pulse blaster constants
    LASER_STRETCH = 0; % we measured that the laser pulses are stretched by 50 ns
    LASER_DELAY = 600; % previous value was 840 ns. Not sure why this changed
    RF_STRETCH = 0; % TODO: measure this value
    res                   = 100;
    BUFFER                = 100;
    t_laser               = getN(handles.t_laser);
    t_laser_actual        = t_laser - LASER_STRETCH; % 400 ns is how long the laser is stretched
    t_rf                  = getN(handles.t_rf);
    
    % pulse blaster pins (where voltage signal controlling hardware is coming from)
    LASER_PIN = 0;
    RF_SWITCH_PIN = 1;
    BATH_SWITCH_PIN = 4;
    CAMERA_PIN = 3;
    
    % get parameters from GUI
    NV_rf_power                     = getN(handles.NV_power);
    NV_rf                           = getN(handles.NV_rf);
    NV_rf_power_2                   = getN(handles.NV_rf_power_2);
    NV_rf_2                         = getN(handles.NV_rf_2);
    if NV_rf_2 ~= 0
        dq = 1;
    else
        dq = 0;
    end
    
    ddq = getV(handles.ddq);
    
    exposure_time_sec               = getN(handles.exp_time) / 1000;        % seconds. setting zero will result in minimum possible (but non-zero) exposure time
    tau_start                       = getN(handles.tau_start);
    tau_end                         = getN(handles.tau_end);
    tau_step                        = getN(handles.tau_step);
    
    taus                            = tau_start : tau_step : tau_end;
    num_taus             = length(taus);          % number of frequency steps
    
    num_sweeps                      = 5
    if bath_sweep
        bath_rf_start                   = getN(handles.bath_rf_start);        % frequency in GHz
        bath_rf_end                     = getN(handles.bath_rf_end);          % frequency in GHz
        bath_rf_step                    = getN(handles.bath_rf_step);
        bath_rf_power                   = getN(handles.bath_power);
        bath_rfs                        = bath_rf_start : bath_rf_step : bath_rf_end;
    else    
        bath_rfs                        = [];
    end
    
    % get binning/imaging parameters
    binning     = getN(handles.binning);
    image_size  = getN(handles.image_size);

    checkbinningandimagesize(binning, image_size);
    
    % kinetic time and number of images
    exposure_time         = 0.004; % seconds! for pulsed, use the minimum exposure time and repeat that
    kin_time              = get_kin_time(exposure_time, image_size, binning); % total time to take an image (inc. readout and refresh)

    % get number of images per RF pulse duration
    cycle_duration        = t_laser + taus + t_rf - 2*RF_STRETCH + 2 * BUFFER;
    images_per_step       = imagesperdutycycle(t_laser, cycle_duration, exposure_time, exposure_time_sec);
    num_images            = sum(images_per_step) * num_sweeps;
    
    %% initialize data arrays
    raw_rf_off       = {[num_taus, num_sweeps]};
    raw_rf_on        = {[num_taus, num_sweeps]};
    
    avg_scan              = zeros(num_taus, 1);
    pl_array              = zeros(num_taus, 1);
    ramseys               = {};
    bath_sweep_ramseys    = {};
    
    %% initialize hardware setup 
    autofocus;       
    hardware = pulsed_hardware; % create instance of hardware class  
    if dq
        disp('initializing dq hardware')
    else
        disp('initializing hardware')
    end

    if ~bath_sweep
        hardware.init(binning, image_size, exposure_time, num_images, NV_rf, NV_rf_power, NV_rf_2, NV_rf_power_2, ddq);  % initialize instance
    end
    
    %% loop over bath frequencies
    
    if ~isempty(bath_rfs)
        for b = 1:length(bath_rfs)
            if bath_sweep
                disp(['running bath rf ' num2str(bath_rfs(b)) ' MHz'])
            end
            
            if bath_sweep
                if b > 1
                    autofocus;
                end
                ddq=1;
                hardware.init(binning, image_size, exposure_time, num_images, NV_rf, NV_rf_power, NV_rf_2, NV_rf_power_2, {ddq, bath_rfs(b), bath_rf_power});  % initialize instance
            end   
            
                ramseysweepscript;
        
                bath_avg = zeros(num_taus, 1);
                for j = 1:num_sweeps
                    bath_avg = bath_avg + ramseys{j};
                end
                bath_sweep_ramseys{b} = bath_avg;
                
            if bath_sweep
                 hardware.kill();
            end
        end
        
        % save again...
        ramsey_stufftosave;
        save([data_folder '\' mat_file_name], 'd','-v7.3')
    else
        ramseysweepscript;
    end
    
    %% finishing / cleaning up    
    % kill hardware object
    if ~bath_sweep
        hardware.kill()
    end
        
    %% try to plot full sweep
    try 
        % plot average sweep figure (to be displayed and logged)
        figure(3); clf;
        plotaxes = gca;

        mean_pl_array = zeros(num_taus, 1);
        
        for ram = 1:num_sweeps
            mean_pl_array = mean_pl_array + ramseys{ram};
        end
        
%         mean_pl_array     = mean_pl_array / num_sweeps;
        
        plot_pl_array     = mean_pl_array - mean(mean_pl_array(:));
        
        %% plot goes here       
        plot(plotaxes,taus,plot_pl_array);
        hold(plotaxes, 'on');
        [final_fit, ~, fit_tau, params] = guessandfitramsey(taus, plot_pl_array);
%         [final_fit,fit_tau, ~,params] = damped_sine_fitter(taus,plot_pl_array, 1);
        plot(plotaxes,fit_tau, final_fit, 'r','LineWidth',2);
        xlabel(plotaxes,'free evolution time (ns)');
        ylabel(plotaxes,'ramsey contrast');
        title(plotaxes,['T^*_2 = ' num2str(params(2)/1000) ' us, mod = ' num2str(params(3)/2*pi * 100 * 1000) ' kHz'])
        axis(plotaxes,'tight');
        
        change_font_size;
        
        cla(handles.axes1);
        
        hold(handles.axes1,'on');
        plot(handles.axes1, taus, plot_pl_array);
        plot(handles.axes1,fit_tau,final_fit,'r','LineWidth',2);
        
        ramsey_fitstufftosave;
    catch
        disp('a full sweep has not been run')
    end
    
    
    %% save data  
    if abort
        disp('aborted, saving data')
        ramsey_stufftosave;
        save([data_folder '\' mat_file_name], 'd','-v7.3') 
    end
        savefig(figure(3),[data_folder '\' final_fig_name]) 
        figname = [dateandtime final_fig_name];
        savefig(figure(3), [log_folder '\' figname])

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
end
