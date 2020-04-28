classdef pulsed_hardware < handle
    % pulsed_hardware is an object that encapsulates hardware interactions
    % including:
    %   -WINDFREAK SynthHD dual channel RF generator
    %   -Image acquisition
    % 
    % Only one Hardware object needs to be created for a GUI; simply kill()
    % and redo the init() call to re-program the hardware.
    
    
    
    properties
        rf_sweeper                      % rf_sweeper SYNTH NV 
        rf_sweeper_bath                 % rf_sweeper SYNTH HD
        vid                             % camera object
        is_initialized                  % boolean flag; '1' if this is already initialized
        exposure_time_sec               % exposure time of camera image in seconds
        NV_rf                           % rf_frequency
        NV_rf_power                     % RF power in dBm
        NV_rf_2                         % rf_frequency
        NV_rf_power_2                   % RF power in dBm
        bath_rf                         % rf_frequency
        bath_power                   % RF power in dBm
        ccd_size                        % image size
        capture_taken                   % boolean flag; '1' if a picture was taken with this initialized object
        images_per_freq                 % number of images taken at each frequency step
        binning                         % binning of camera pixels
        dq
        num_images
        ddq
    end
    
    properties (Constant)
        % Hamamatsu camera constants (from data sheet)
        DARK_OFFSET = 100;              % hamamatsu dark offset: 100 extra counts each time a picture is taken
        CONVERSION_FACTOR = 0.46;       % hamamatsu average photons/count
    end
    
    methods
        function obj = init(obj, binning, image_size, exposure_time, num_images, NV_rf, NV_rf_power, NV_rf_2, NV_rf_power_2, varargin)
            % initializes the Hamamatsu camera, DAQ system, and RF sweeper
            % binning_index: index corresponding to obj.binning setting
            % ccd_size_index: index corresponding to ccd size
            
            if ~isempty(varargin) 
                argument = varargin{1};
                
                if length(argument) > 1 
                    ddq         = argument{1};
                    bath_rf     = argument{2};
                    bath_power  = argument{3};       
                else
                    ddq = argument;
                    bath_rf     = 0;
                    bath_power  = 0;
                end
            else
                ddq = 0;
            end
            
            if obj.is_initialized
                error('hardware is already initialized')
            end
            
            %% SET OBJECT FIELDS
            % see "Properties" for description of fields
            obj.exposure_time_sec = exposure_time;
            obj.num_images = num_images;
            obj.NV_rf = NV_rf;
            obj.NV_rf_power = NV_rf_power;
            obj.NV_rf_2 = NV_rf_2;
            obj.NV_rf_power_2 = NV_rf_power_2;
            obj.ddq = ddq;
            
            if bath_rf > 0
                obj.bath_rf = bath_rf;
                obj.bath_power = bath_power;
            end
            
            %% Set up HP RF SWEEPER
            if obj.ddq > 0
                if obj.ddq == 1
                    paddress = 19;             
                elseif obj.ddq == 2
                    paddress = 1;
                end
                obj.rf_sweeper_bath = instrfind('Type', 'gpib', 'BoardIndex', 0, 'PrimaryAddress', paddress);

                % Create the GPIB object if it does not exist
                if isempty(obj.rf_sweeper_bath)
                    % this is the key line. works without the rest unless program halts or something
                    obj.rf_sweeper_bath = gpib('ni', 0, paddress);
                else
                    fclose(obj.rf_sweeper_bath);
                    obj.rf_sweeper_bath = obj.rf_sweeper_bath(1);
                end

                try
                    fopen(obj.rf_sweeper_bath);    % Connect to rf generator object, obj.rf_sweeper. 
                catch ME_OUTSIDE
                    error('turn on the RF sweeper!')
                end
                set(obj.rf_sweeper_bath, 'Timeout', 2);
            end
            
            obj.rf_sweeper = visa('ni', 'ASRL4::INSTR');

            % Create the visa object if it does not exist
            if isempty(obj.rf_sweeper)
                % this is the key line. works without the rest unless program halts or something
                obj.rf_sweeper = visa('ni', 'ASRL4::INSTR');
            else
                fclose(obj.rf_sweeper);
                obj.rf_sweeper = obj.rf_sweeper(1);
            end

            try
                fopen(obj.rf_sweeper);    % Connect to rf generator object, obj.rf_sweeper. 
            catch ME_OUTSIDE
                error('turn on the RF sweeper!')
            end
                set(obj.rf_sweeper, 'Timeout', 2);      
            

            % NV RF gen is channel A
            disp('initializing synthNV RF generator')
            fprintf(obj.rf_sweeper, 'C1');                                           % Channel A setup
            fprintf(obj.rf_sweeper, ['f' num2str(obj.NV_rf * 10^3)]);         % Sets RF frequency as rf_frequency
            fprintf(obj.rf_sweeper, 'h0');                                           % Mute the RF signal
            fprintf(obj.rf_sweeper, 'E1r1');                                         % RF off
            fprintf(obj.rf_sweeper, 'c0');                                           % Sets power sweep mode off
            fprintf(obj.rf_sweeper, ['W' num2str(obj.NV_rf_power)]);                    % Sets the power level 
            fprintf(obj.rf_sweeper, 'g0');                                           % Turn off sweep
            
            if NV_rf_2 ~= 0
                obj.dq = 1;
                fprintf(obj.rf_sweeper, 'C0');                                           % Channel A setup
                fprintf(obj.rf_sweeper, ['f' num2str(obj.NV_rf_2 * 10^3)]);         % Sets RF frequency as rf_frequency
                fprintf(obj.rf_sweeper, 'h0');                                           % Mute the RF signal
                fprintf(obj.rf_sweeper, 'E1r1');                                         % RF off
                fprintf(obj.rf_sweeper, 'c0');                                           % Sets power sweep mode off
                fprintf(obj.rf_sweeper, ['W' num2str(obj.NV_rf_power_2)]);                    % Sets the power level 
                fprintf(obj.rf_sweeper, 'g0');                                           % Turn off sweep
            else
                obj.dq = 0;
            end    
            
            % bath RF gen is ddq generator
            if obj.ddq == 1
                disp('initializing HP RF generator')
                fprintf(obj.rf_sweeper_bath, 'PS0');                              % Sets Power Sweep Mode Off
                fprintf(obj.rf_sweeper_bath, 'PL %d DB', obj.bath_power);                   % Sets the power level
                fprintf(obj.rf_sweeper_bath, 'CW %d MZ', obj.bath_rf);               % Sets start frequency as start_freq
                fprintf(obj.rf_sweeper_bath, 'RF1');
            elseif obj.ddq == 2
                disp('initializing R&S RF generator')
                fprintf(obj.rf_sweeper_bath, char(':SOUR:FREQ:MODE CW '));
                fprintf(obj.rf_sweeper_bath, char(['POW ', num2str(obj.bath_power), 'dBm']));
                fprintf(obj.rf_sweeper_bath, char([':SOUR:FREQ:CW ', num2str(obj.bath_rf) 'MHz']));            
                fprintf(obj.rf_sweeper_bath, 'OUTP:STAT ON');
            end
            
            %% SET UP CCD AREA
            obj.binning = binning;
            if binning == 0
            elseif binning == 2 
                binning_index = 2;
            elseif binning == 4
                binning_index = 3;
            end
            
            obj.ccd_size = image_size;

            if obj.binning * obj.ccd_size > 2048 % if obj.binning * ccd area is greater than total camera pixel number
                error('invalid image size requested. check obj.binning and ccd size.')
            end

            imagingM = {'MONO16_2048x2048_FastMode','MONO16_BIN2x2_1024x1024_FastMode','MONO16_BIN4x4_512x512_FastMode'};
            imagingMode = imagingM{binning_index};

            % region of interest (intensity sampling region)    
            ROIPosition = [2048/obj.binning/2 - obj.ccd_size/2 2048/obj.binning/2 - obj.ccd_size/2 obj.ccd_size obj.ccd_size];

            
            %% INITIALIZE VIDEO OBJECT
            try
                obj.vid                     = videoinput('hamamatsu', 1, imagingMode);
                 
            catch ME
                error('turn on Hamamatsu camera!')
            end
                
            src                         = getselectedsource(obj.vid);
            MAX_EXPOSURE_TIME           = 1;

            if obj.exposure_time_sec > MAX_EXPOSURE_TIME
                error('desired exposure time is too large for Hamamatsu camera')
            end
            
            src.ExposureTime            = obj.exposure_time_sec; % assign exposure time
    
            triggerconfig(obj.vid, 'hardware', 'RisingEdge', 'EdgeTrigger');
            set(obj.vid,'Timeout',5);
            obj.vid.FramesPerTrigger    = 1;
            obj.vid.TriggerRepeat       = num_images - 1;
            obj.vid.ROIPosition         = ROIPosition; 
            obj.vid 
            start(obj.vid);
            %% set flag to initialized
            obj.is_initialized                     = 1;
        end

        
        
        function image = capture(obj, ims_per_step)
            % With the initialized parameters, capture and return an image
            
            % check if this object is initialized
            if not(obj.is_initialized)
                error('Cannot capture image on Hardware object that is not initialized');
            end
            
            % Capture an image using the initialized Hardware object and it
            % corresponding capture parameters.

            %% TAKE PIX
            % Sets RF power ON
            
            fprintf(obj.rf_sweeper, 'C1');
            fprintf(obj.rf_sweeper, 'h1');  
            if obj.dq
                fprintf(obj.rf_sweeper, 'C0');
                fprintf(obj.rf_sweeper, 'h1'); 
            end
                

            
            % START PULSE BLASTER
            if PB.start() < 0 % trigger laser, RF switch, and/or DAQ
                error('Pulseblaster could not start')
            end
            
            unavailable=1;
            while get(obj.vid,'FramesAvailable') < ims_per_step  %Wait until at least 1 frame is available
                  unavailable=unavailable+1;
                  if unavailable > ims_per_step + 10000
                      image = [];
                      PB.stop();

                        fprintf(obj.rf_sweeper, 'C1');
                        fprintf(obj.rf_sweeper, 'h0');
                        fprintf(obj.rf_sweeper, 'C0');
                        fprintf(obj.rf_sweeper, 'h0');

                      return
                  end
            end
            PB.stop();

            fprintf(obj.rf_sweeper, 'C1');
            fprintf(obj.rf_sweeper, 'h0');
            fprintf(obj.rf_sweeper, 'C0');
            fprintf(obj.rf_sweeper, 'h0');

            
            % now get images from camera
            try   
                image = squeeze(double(getdata(obj.vid, obj.vid.FramesAvailable)));
            catch me
                disp(me)
                obj.vid.FramesAcquired
                obj.vid.TriggerRepeat
                kill(obj)
                error('frames acquired may not be equal to frames requested')
            end
            
            
        end
        
           
        % CHANGE RF FREQUENCY
        function set_freq(obj, frequency)

            if not(obj.is_initialized)
                error('initialize the Hardware object first')
            end
            
            fprintf(obj.rf_sweeper, 'C0'); 
            fprintf(obj.rf_sweeper, ['f' num2str(frequency * 10^3)]);  
            
            
        end            
        
        function set_bath_freq(obj, frequency)
           
            if not(obj.is_initialized)
                error('initialize the Hardware object first')
            end
            fprintf(obj.rf_sweeper_bath, 'CW %d MZ', frequency);               % Sets start frequency as start_freq
        end
        
        % KILL
        function kill(obj)
            % called after init() and measurement_script() to kill current
            % hardware connections
            
            if obj.is_initialized == 0
                error('Hardware is not initialized')
            end
                
            % KILL HAMAMATSU CAMERA
            stop(obj.vid)
            delete(obj.vid)

            % KILL DAQ AND RF SWEEPER
            fprintf(obj.rf_sweeper, 'C0');   % Channel A
            fprintf(obj.rf_sweeper, 'h0');   % RF muted
            fprintf(obj.rf_sweeper, 'E0r0'); % RF off
            fprintf(obj.rf_sweeper, 'C1');   % Channel B
            fprintf(obj.rf_sweeper, 'h0');   % RF muted
            fprintf(obj.rf_sweeper, 'E0r0'); % RF off
            
            fprintf(obj.rf_sweeper, 'C1');   % Channel A
            fprintf(obj.rf_sweeper, 'h0');   % RF muted
            fprintf(obj.rf_sweeper, 'E0r0'); % RF off
            fprintf(obj.rf_sweeper, 'C1');   % Channel B
            fprintf(obj.rf_sweeper, 'h0');   % RF muted
            fprintf(obj.rf_sweeper, 'E0r0'); % RF off
            
            fclose(obj.rf_sweeper);          % close 
            delete(obj.rf_sweeper);          % delete
            
            if obj.ddq > 0
                
                if obj.ddq == 1
                    fprintf(obj.rf_sweeper_bath, 'RF0');   % RF muted
                elseif obj.ddq == 2
                    fprintf(obj.rf_sweeper_bath, 'OUTP:STAT OFF');   % RF off
                end
                
                fclose(obj.rf_sweeper_bath);
                delete(obj.rf_sweeper_bath);
            end
            obj.is_initialized = 0;
        end
    end
    
    methods(Static)
        
        function photons = counts2photons(camera_counts)
            % converts counts (from Hamamatsu camera) to photons
            % camera counts: number of counts over integration region
            % rf_off_counts: measured counts during laser excitation integration with RF off
                actual_counts = camera_counts - (Hardware.DARK_OFFSET);
                photons = actual_counts * Hardware.CONVERSION_FACTOR;
        end
    end
end