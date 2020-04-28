function spinecho(handles, varargin)
    cla(handles.axes1)
    cla(handles.axes2)
    normalize = 1;
    data_from_middle = 0;

    if getN(handles.bath_power) > -30
        bath_rf_on      = 1;
    else
        bath_rf_on      = 0;
    end
    
    %% file names and plot labels
    dateandtime = get_dateandtime;    
    x_label = 'free evolution time (us)';
    y_label = 'normalized pl';
    if ~isempty(varargin)
        mat_file_name = varargin{1};
    else
        mat_file_name = 'spinecho_sweep.mat';
    end
    final_fig_name= 'spinecho_sweep.fig';
    
    %% define where things are saved
    data_folder = 'E:\Dropbox\Projects\magPI\pulses_GUI\spinecho_sweeps';
    log_folder  = 'E:\Dropbox\Projects\magPI\pulses_GUI\spinecho_log'; % averaged sweep figure is logged here
  
    %% constants
    % pulse blaster constants
    LASER_STRETCH = 0; % we measured that the laser pulses are stretched by 50 ns
    LASER_DELAY = 600; % previous value was 840 ns. Not sure why this changed
    RF_STRETCH = 0; % TODO: measure this value
    res                   = 100;
    t_laser               = getN(handles.t_laser);
    t_laser_actual        = t_laser - LASER_STRETCH; % 400 ns is how long the laser is stretched
    t_rf                  = getN(handles.t_rf);
    ddq                   = getV(handles.ddq);
    
    % pulse blaster pins (where voltage signal controlling hardware is coming from)
    LASER_PIN = 0;
    RF_SWITCH_PIN = 1;
    BATH_SWITCH_PIN = 4;
    CAMERA_PIN = 3;
    
    bath_rf                         = getN(handles.bath_rf_start);
    bath_t_rf                       = getN(handles.bath_t_rf);
    bath_rf_power                   = getN(handles.bath_power);
    
    % get parameters from GUI
    NV_rf_power                     = getN(handles.NV_power);
    NV_rf                           = getN(handles.NV_rf);
    NV_rf_power_2                   = getN(handles.NV_rf_power_2);
    NV_rf_2                         = getN(handles.NV_rf_2);
    exposure_time_sec               = getN(handles.exp_time) / 1000;        % seconds. setting zero will result in minimum possible (but non-zero) exposure time
    tau_start                       = getN(handles.tau_start);
    tau_end                         = getN(handles.tau_end);
    tau_step                        = getN(handles.tau_step);
    
    taus                            = tau_start : tau_step : tau_end;
    num_pulse_durations             = length(taus);          % number of frequency steps
    num_sweeps                      = 10;
  
    % get binning/imaging parameters
    binning     = getN(handles.binning);
    image_size  = getN(handles.image_size);

    checkbinningandimagesize(binning, image_size);
    
    % kinetic time and number of images
    exposure_time         = 0.004; % seconds! for pulsed, use the minimum exposure time and repeat that
    kin_time              = get_kin_time(exposure_time, image_size, binning); % total time to take an image (inc. readout and refresh)

    % get number of images per RF pulse duration
    cycle_duration        = t_laser_actual + taus + t_rf - RF_STRETCH;
    images_per_step       = imagesperdutycycle(t_laser, cycle_duration, exposure_time, exposure_time_sec);
    num_images            = sum(images_per_step);
    images_per_freq       = round(exposure_time_sec / kin_time);
    images_per_freq       = mod(images_per_freq, 2) + images_per_freq;
    
    %% initialize data arrays
    raw_rf_on             = {}; % all rf_on images
    raw_rf_off            = {}; % all rf_off images
    avg_scan              = zeros(num_pulse_durations, num_sweeps);
    pl_array              = zeros(num_pulse_durations, 1);
    
    %% initialize hardware setup 
    hardware = pulsed_hardware; % create instance of hardware class
    disp('initializing hardware')
    
    %% loop through number of sweeps
    for i = 1:num_sweeps
        cla(handles.axes1)
        cla(handles.axes2)
        % check to see if user selected abort
        abort = getV(handles.abort);  
        if abort > 0
            disp('scan aborted')
            break;
        end
        disp(['running frequency sweep ' num2str(i) ' out of ' num2str(num_sweeps)])
        if bath_rf_on
            hardware.init(binning, image_size, exposure_time, num_images, NV_rf, NV_rf_power, NV_rf_2, NV_rf_power_2, {ddq, bath_rf, bath_power});
        else      
            hardware.init(binning, image_size, exposure_time, num_images, NV_rf, NV_rf_power, NV_rf_2, NV_rf_power_2, ddq);  % initialize instance
        end
        spinechosweepscript;
        hardware.kill()
        avg_scan(:,i) = pl_array;
    end
        
        %% if user hit abort
        if abort ~= 1
            % average the data
            norm_avg_scan = sum(avg_scan,2) / size(avg_scan,2);

            % plot freq scans
            cla(handles.axes1);
            plot(handles.axes1,2*taus, norm_avg_scan,'.-b');
            box(handles.axes1, 'on')
            xlabel(handles.axes1,x_label)        
            ylabel(handles.axes1,y_label)
            hold(handles.axes1, 'on')
            axis(handles.axes1, 'tight')
            
            % plot RF off
            axes(handles.axes2);
            imagesc(summed);
            image_title = strcat('RF Off Image - see integration region');
            title(image_title)
            colorbar(handles.axes2)
            hold(handles.axes2, 'on')
            axis(handles.axes2, 'tight')
        end
       
        

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
        % SAVE STUFF IN 'd' OBJECT
        % this script creates an object 'd' that all the data is stored in
        spinecho_stufftosave;

        disp('saving data for this sweep')
        % save data
        save([data_folder '\' mat_file_name], 'd','-v7.3') 

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
    
    %% try to plot full sweep
    try 
        % plot average sweep figure (to be displayed and logged)
        figure(3); clf;
        plotaxes = gca;
        plot(plotaxes,taus, norm_avg_scan,'.-b');
        hold(plotaxes,'on')
        box(plotaxes,'on')
        xlabel(plotaxes,x_label)
        ylabel(plotaxes,y_label)
        hold(plotaxes,'on')
        figtitle = ['DEER curve: NV-RF (GHz) power = ' num2str(power) ', RF (MHz) power = ' num2str(bath_rf_power) ' dBm, Num freqs = ' num2str(num_freqs) ' , Exposure time = ' num2str(exposure_time) ' s, \pi Pulse = ' num2str(t_rf) ' ns, '  num2str(num_sweeps) ' sweep(s)'];
        title(plotaxes,figtitle,'FontSize',8);
        axis(plotaxes,'tight')
    catch
        disp('a full sweep has not been run')
    end
    
    
    %% save data  
    if abort
        spinecho_stufftosave;
    end
        disp('saving data')
        savefig(figure(3),[data_folder '\' final_fig_name]) 
        save([data_folder '\' mat_file_name], 'd', '-v7.3')

        figname = [dateandtime final_fig_name];
        savefig(figure(3), [log_folder '\' figname])

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
end
