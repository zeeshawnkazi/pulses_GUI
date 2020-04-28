function rabi(handles, varargin)
    cla(handles.axes1)
    cla(handles.axes2)
    data_from_middle = 0;
    %% file names and plot labels
    dateandtime = get_dateandtime;
    x_label = 'RF pulse time (us)';
    y_label = 'normalized pl';
    if ~isempty(varargin)
        mat_file_name = varargin{1};
    else
        mat_file_name = 'rabi_sweep.mat';
    end
    final_fig_name= 'rabi_sweep.fig';
    
    %% define where things are saved
    data_folder = 'E:\Dropbox\Projects\magPI\pulses_GUI\rabi_sweeps';
    log_folder  = 'E:\Dropbox\Projects\magPI\pulses_GUI\rabi_log'; % averaged sweep figure is logged here
       
    
    %% global constants
    % pulse blaster constants
    LASER_STRETCH = 0; % we measured that the laser pulses are stretched by 50 ns
    LASER_DELAY = 600; % previous value was 840 ns. Not sure why this changed
    RF_STRETCH = 0; % TODO: measure this value
    res                   = 100;
    t_laser               = getN(handles.t_laser);
    t_laser_actual        = t_laser - LASER_STRETCH; % 400 ns is how long the laser is stretched
    
    % pulse blaster pins (where voltage signal controlling hardware is coming from)
    LASER_PIN = 0;
    ddq = getV(handles.ddq);
    if ddq == 1
        rhode = getV(handles.rhodeorhp);
        if rhode 
            ddq = 2;
        end
        RF_SWITCH_PIN = 4;
    else
        RF_SWITCH_PIN = 1;
    end
    CAMERA_PIN = 3;
    
    % get parameters from GUI
    NV_rf_power                     = getN(handles.NV_power);
    NV_rf                           = getN(handles.NV_rf);
    exposure_time_sec               = getN(handles.exp_time) / 1000;        % seconds. setting zero will result in minimum possible (but non-zero) exposure time
    rabi_time_start                 = getN(handles.t_rf_start);
    rabi_time_end                   = getN(handles.t_rf_end);
    rabi_time_step                  = getN(handles.t_rf_step);
    
    pulse_durations                 = rabi_time_start : rabi_time_step : rabi_time_end;
    num_pulse_durations             = length(pulse_durations);          % number of frequency steps
    num_sweeps                      = 1;
  
    % get binning/imaging parameters
    binning     = getN(handles.binning);
    image_size  = getN(handles.image_size);

    checkbinningandimagesize(binning, image_size);
    
    % kinetic time and number of images
    exposure_time         = 0.004; % seconds! for pulsed, use the minimum exposure time and repeat that
    kin_time              = get_kin_time(exposure_time, image_size, binning); % total time to take an image (inc. readout and refresh)

    % get number of images per RF pulse duration
    cycle_duration        = t_laser_actual + pulse_durations - RF_STRETCH;
    images_per_step       = imagesperdutycycle(t_laser, cycle_duration, exposure_time, exposure_time_sec, 10);
    num_images            = sum(images_per_step);
    images_per_freq       = round(exposure_time_sec / kin_time);
    images_per_freq       = mod(images_per_freq, 2) + images_per_freq;
    
    %% initialize data arrays
    raw_rf_on             = {}; % all rf_on images
    raw_rf_off            = {}; % all rf_off images
    avg_scan              = zeros(num_pulse_durations, 1);
    pl_array              = zeros(num_pulse_durations, 1);
    
    %% initialize hardware setup 
    hardware = pulsed_hardware; % create instance of hardware class
    disp('initializing hardware')
%     hardware.init(binning, image_size, exposure_time, num_images, NV_rf, NV_rf_power, 0, -60,0);  % initialize instance
    hardware.init(binning, image_size, exposure_time, num_images, NV_rf, NV_rf_power, 0, -60,{ddq, NV_rf*10^3, NV_rf_power});  % initialize instance
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
        
        % step through RFs, take an image at each frequency
        for f = 1:length(pulse_durations)
            disp(['rf pulse duration = ' num2str(pulse_durations(f)) ' ns'])
            pause(0)
            abort = getV(handles.abort);  % check to see if user selected abort
            if abort > 0
                disp('scan aborted')
                break;
            end
            
            
            t_rf                  = pulse_durations(f);        
            t_rf_actual           = t_rf - RF_STRETCH;
            
            kin_time_ns           = kin_time * 10^9;    
            cycle_length          = t_laser_actual + t_rf;
            images_per_duration   = images_per_step(f);

            num_loops             = round(kin_time_ns / cycle_length);

            if mod(cycle_length, res) ~= 0
                error(['please adjust t_laser (' num2str(t_laser) ') and t_rf (' num2str(t_rf) ') such that the total cycle length (' num2str(cycle_length) ') is divisble by ' num2str(res)])
            end

            pb1 = PBInd([LASER_PIN, RF_SWITCH_PIN, CAMERA_PIN], cycle_length, res, 0); % auto stop is turned off, so we have to manually stop programming later
            PB.start_programming('PULSE_PROGRAM');


            for image = 1:(images_per_duration / 2)
                %% PICTURE 1 - RF ON
                pb1.on(CAMERA_PIN, 0, cycle_length);
                pb1.on(LASER_PIN, 0, t_laser_actual);
                pb1.on(RF_SWITCH_PIN, t_laser_actual, t_rf_actual);
                pb1.program([-LASER_DELAY, 0, 0], num_loops / 2); % program first half of duty cycle

                pb1.on(LASER_PIN, 0, t_laser_actual);
                pb1.on(RF_SWITCH_PIN, t_laser_actual, t_rf_actual);
                pb1.off(CAMERA_PIN, 0, cycle_length); % camera trigger is now off (second half of duty cycle)
                pb1.program([-LASER_DELAY, 0, 0], num_loops / 2); % program second half of duty cycle

                %% PICTURE 2 - RF OFF
                pb1.on(CAMERA_PIN, 0, cycle_length);
                pb1.on(LASER_PIN, 0, t_laser_actual);
                pb1.off(RF_SWITCH_PIN, t_laser_actual, t_rf_actual);
                pb1.program([-LASER_DELAY, 0, 0], num_loops / 2); % program first half of duty cycle

                pb1.off(CAMERA_PIN, 0, cycle_length); % camera trigger is now off (second half of duty cycle)
                pb1.on(LASER_PIN, 0, t_laser_actual);
                pb1.off(RF_SWITCH_PIN, t_laser_actual, t_rf_actual);
                pb1.program([-LASER_DELAY, 0, 0], num_loops / 2); % program second half of duty cycle

            end

            % print instructions to pulse blaster
            PB.inst_pbonly(0, 'STOP', 0, 2 * PB.MIN_INSTR_LENGTH);
            PB.stop_programming(); % since auto_stop is off, manually turn off

            % take data (including pulse sequence)
            images = hardware.capture(images_per_duration);
                         
            % get RF on image and RF off image and separate them
            raw_rf_on_temp    = images(:, :, 1:2:end); % every other image is RF on
            raw_rf_off_temp   = images(:, :, 2:2:end); % every other image is RF off
            
            raw_rf_on{f}    = raw_rf_on_temp; % rawRFUnclet
            raw_rf_off{f}   = raw_rf_off_temp;
            
            % total RF off images are summed up -> this summed image gives
            % us a photon count rate to compute sensitivity
            summed = sum(raw_rf_on_temp, 3);
            on_summed = sum(raw_rf_on_temp, 3);
            
            % plot RF off
            image_title = strcat('RF on image');
            imagesc(handles.axes2, on_summed);
            title(handles.axes2,image_title)
            colorbar(handles.axes2)          
            
            % for sensitivity, initialize number of camera counts
            photoelectrons = 0;
            % initialize normalized PL element (data to be plotted)
            norm = 0;
            
            % loop through each RFon/RFoff pair and get photoluminescence
            % divided by background 
            for k = 1:(images_per_duration / 2) 
                rf_on_image = raw_rf_on_temp(:, :, k);
                rf_off_image = raw_rf_off_temp(:, :, k);
                
% %               % get RF on and RF off counts in 1 um^2 centered around x0, y0
                if data_from_middle
                    x0 = image_size / 2;
                    y0 = image_size/2;
                    rw = 2 * 8 / binning;
                    pl = average_counts(rf_on_image, x0, y0, rw);
                    bg = average_counts(rf_off_image, x0, y0, rw);
                else
                    pl = mean(rf_on_image(:));
                    bg = mean(rf_off_image(:));
                end
                
                % RF off counts
                photoelectrons = photoelectrons + bg;
                % normalized PL data point 
                norm = norm + pl / bg;
            end

            % normalize deer_contrast to 1
            norm = norm / (images_per_duration / 2); 
            % put this data in deer_contrast
            pl_array(f) = norm; % this is the final data point
            
            % plot freq scans           
            plot(handles.axes1, pulse_durations(1:f) * 10^-3, pl_array(1:f),'.-b');
            box(handles.axes1,'on')
            xlabel(handles.axes1,'pulse duration (us)');
            ylabel(handles.axes1,'Normalized PL');
            hold(handles.axes1,'on')
            axis(handles.axes1,'tight')
        end
        
        %% if user hit abort
        if abort ~= 1
            % average the data
            avg_scan = avg_scan + pl_array;
            norm_avg_scan = avg_scan / i;

            % plot freq scans
            cla(handles.axes1);
            axes(handles.axes1);
            plot(handles.axes1,pulse_durations, norm_avg_scan,'.-b');
            box(handles.axes1,'on')
            xlabel(handles.axes1,x_label)        
            ylabel(handles.axes1,y_label)
            hold(handles.axes1,'on')
            axis(handles.axes1,'tight')
            
            % plot RF off
            axes(handles.axes2);
            imagesc(handles.axes2,summed);
            image_title = strcat('RF Off Image - see integration region');
            title(handles.axes2,image_title)
            hold(handles.axes2,'on')
            colorbar(handles.axes2)
            axis(handles.axes2,'tight') 
            
        else
            break
        end
       
        

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
        % SAVE STUFF IN 'd' OBJECT
        % this script creates an object 'd' that all the data is stored in
        rabi_stufftosave;

        disp('saving data for this sweep')
        % save data
        save([data_folder '\' mat_file_name], 'd','-v7.3') 

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
          

    end
    
    %% finishing / cleaning up    
    % kill hardware object
    hardware.kill()
    
    %% try to plot full sweep
    try 
        [final_fit,fit_x,~,~] = damped_sine_fitter(pulse_durations,norm_avg_scan,1);

        n = find(final_fit == min(final_fit(:)));
        pi_pulse   = fit_x(n)
        
        % plot average sweep figure (to be displayed and logged)
        figure(3); clf;
        plotaxes = gca;
        plot(plotaxes,pulse_durations, norm_avg_scan,'.-b');
        hold(plotaxes,'on')
        box(plotaxes,'on')
        xlabel(plotaxes,x_label)
        ylabel(plotaxes,y_label)
        hold(plotaxes,'on')
        plot(plotaxes,fit_x, final_fit, 'r','LineWidth', 2);
        
        axis(plotaxes,'tight')
        title(plotaxes,['Rabi at ' num2str(NV_rf_power) 'dBm, ' num2str(pi_pulse) ' ns \pi-pulse'])
    catch
        disp('a full sweep has not been run')
    end
    
    
    %% save data  
    if abort
        rabi_stufftosave;
    end
        disp('saving data')
        savefig(figure(3),[data_folder '\' final_fig_name]) 
        save([data_folder '\' mat_file_name], 'd', '-v7.3')

        figname = [dateandtime final_fig_name];
        savefig(figure(3), [log_folder '\' figname])

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
end
