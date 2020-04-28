function deer(handles, varargin)
    cla(handles.axes1)
    cla(handles.axes2)
    cla(handles.axes3)
    
    waitsteps =200;
    
    data_from_middle = 0;
    normalize =1;
    
    %% file names
    
    dateandtime = get_dateandtime;
    
    %% plot labels
    x_label = 'bath RF drive (MHz)';
    y_label = 'DEER contrast (%)';
    if ~isempty(varargin)
        mat_file_name = varargin{1};
    else
        mat_file_name = 'DEER_sweep.mat';
    end 
    final_fig_name= 'DEER_sweep.fig';
    data_folder = 'E:\Dropbox\Projects\magPI\pulses_GUI\deer_sweeps';
    log_folder  = 'E:\Dropbox\Projects\magPI\pulses_GUI\deer_log'; % averaged sweep figure is logged here


    %% global constants
    % pulse blaster constants
    LASER_STRETCH = 0; % we measured that the laser pulses are stretched by 50 ns
    LASER_DELAY = 600; % previous value was 840 ns. Not sure why this changed
    RF_STRETCH = 0; % TODO: measure this value
    res                   = 100;
    BUFFER                = 100;
    
    % pulse blaster pins (where voltage signal controlling hardware is coming from)
    LASER_PIN = 0;
    RF_SWITCH_PIN = 1;
    BATH_SWITCH_PIN = 4;
    CAMERA_PIN = 3;
    
    % get parameters from GUI
    bath_rf_start                   = getN(handles.bath_rf_start);        % frequency in GHz
    bath_rf_end                     = getN(handles.bath_rf_end);          % frequency in GHz
    bath_rf_step                    = getN(handles.bath_rf_step);
    bath_rf_power                   = getN(handles.bath_power);
    bath_t_rf                       = getN(handles.bath_t_rf);
    
    tau                             = getN(handles.tau);
    taus                            = tau;
    NV_rf_power                     = getN(handles.NV_power);
    NV_rf                           = getN(handles.NV_rf);
    
    exposure_time_sec               = getN(handles.exp_time) / 1000;        % seconds. setting zero will result in minimum possible (but non-zero) exposure time
    bath_rfs                        = bath_rf_start : bath_rf_step : bath_rf_end;
    
    num_freqs                       = length(bath_rfs);          % number of frequency steps
    num_sweeps                      = 30;
  
    % get binning/imaging parameters
    binning     = getN(handles.binning);
    image_size  = getN(handles.image_size);

    checkbinningandimagesize(binning, image_size);
    
    % kinetic time and number of images
    exposure_time         = 0.004; % seconds! for pulsed, use the minimum exposure time and repeat that
    kin_time              = get_kin_time(exposure_time, image_size, binning); % total time to take an image (inc. readout and refresh)

    % get number of images per RF pulse duration
    t_laser               = getN(handles.t_laser);
    t_laser_actual        = t_laser - LASER_STRETCH; % 400 ns is how long the laser is stretched
    t_rf                  = getN(handles.t_rf);
    t_rf_actual           = t_rf - RF_STRETCH;
    cycle_duration        = t_laser_actual + 2*BUFFER + 2*tau + 2*(t_rf/2 - RF_STRETCH) + t_rf_actual;
    images_per_step       = imagesperdutycycle(t_laser, cycle_duration, exposure_time, exposure_time_sec);
    num_images            = sum(images_per_step)*num_sweeps*num_freqs;
    
    %% initialize data arrays

    raw_rf_on             = {[num_freqs, num_sweeps]}; % all rf_on images
    raw_rf_off            = {[num_freqs, num_sweeps]}; % all rf_off images
    pl_array              = zeros(num_freqs, 1);
    avg_pl_array          = zeros(num_freqs,1);
    
    deers                 = {};
    deer_bath_sweep       = {};
    
        %% program Pulseblaster for DEER
        disp('running DEER measurement')
        display_RFstepsize(bath_rf_start*10^-3, bath_rf_end*10^-3, num_freqs)
    

    hardware = pulsed_hardware; % create instance of hardware class
    disp('initializing hardware')
    ddq=1;
    hardware.init(binning, image_size, exposure_time, num_images, NV_rf, NV_rf_power, 0, -50, {ddq, bath_rfs(1), bath_rf_power});  % initialize instance

    %% loop through number of sweeps   
        % step through RFs, take an image at each frequency
        for b = 1:length(bath_rfs)                      
            disp(['bath rf = ' num2str(bath_rfs(b)) ' MHz'])
            hardware.set_bath_freq(bath_rfs(b));
            % check to see if user selected abort
            abort = getV(handles.abort);  
            if abort > 0
                disp('scan aborted')
                break;
            end        
 
           
            if ~mod(b,waitsteps) && b > 1
                hardware.kill();
                autofocus;
                imaqreset;
                pause(10);
                hardware.init(binning, image_size, exposure_time, num_images, NV_rf, NV_rf_power, 0, -50, {ddq, bath_rfs(1), bath_rf_power});  % initialize instance
            end
            deersweepscript;
                          
            avg_deer = 0;
            for j = 1:num_sweeps
                avg_deer = avg_deer + deers{j};
            end
            avg_pl_array(b)       = avg_deer/num_sweeps;
            deer_bath_sweep{b}    = avg_deer;
            
            % plot freq scans
            cla(handles.axes1);
            plot(handles.axes1, bath_rfs(1:b), avg_pl_array(1:b),'.-b');
            box(handles.axes1, 'on')
            xlabel(handles.axes1,'bath drive frequency (MHz)')
            ylabel(handles.axes1,'Normalized PL')
            hold(handles.axes1, 'on')
            axis(handles.axes1, 'tight')
            
            
            if ~mod(b,waitsteps)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
            % SAVE STUFF IN 'd' OBJECT
            % this script creates an object 'd' that all the data is stored in
            deer_stufftosave;

            disp(['saving data for the last ' num2str(waitsteps) ' steps'])
            % save data
            save([data_folder '\' mat_file_name], 'd','-v7.3') 

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            end
            
            

        end
        
        hardware.kill();
        
        %% if user hit abort
        if abort ~= 1
            % plot freq scans
            plot(handles.axes1, bath_rfs, avg_pl_array,'.-b');
            box(handles.axes1, 'on')
            xlabel(handles.axes1, x_label)            
            ylabel(handles.axes1, y_label)
            hold(handles.axes1, 'on')
            axis(handles.axes1, 'tight')
            
            % plot RF off
            imagesc(handles.axes2, on_summed);
            image_title = strcat('RF on image');
            title(handles.axes2,image_title)
            hold(handles.axes2, 'on')
            axis(handles.axes2, 'tight') 
            colorbar(handles.axes2);
            
        end
        
    
        

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
        % SAVE STUFF IN 'd' OBJECT
        % this script creates an object 'd' that all the data is stored in
        deer_stufftosave;

        disp('saving data for this sweep')
        % save data
        save([data_folder '\' mat_file_name], 'd','-v7.3') 

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        

    
    
    %% try to plot full sweep
    try 
        % plot average sweep figure (to be displayed and logged)
        figure(3); clf;
        plotaxes = gca;
        plot(plotaxes,bath_rfs, avg_pl_array,'.-b');
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
        deer_stufftosave;
    end
        disp('saving data')
        savefig(figure(3),[data_folder '\' final_fig_name]) 
        save([data_folder '\' mat_file_name], 'd', '-v7.3')

        figname = [dateandtime final_fig_name];
        savefig(figure(3), [log_folder '\' figname])

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
end
