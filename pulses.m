function varargout = pulses(varargin)
% PULSES MATLAB code for pulses.fig
%      PULSES, by itself, creates a new PULSES or raises the existing
%      singleton*.
%
%      H = PULSES returns the handle to a new PULSES or the handle to
%      the existing singleton*.
%
%      PULSES('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PULSES.M with the given input arguments.
%
%      PULSES('Property','Value',...) creates a new PULSES or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before pulses_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to pulses_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help pulses

% Last Modified by GUIDE v2.5 05-Mar-2020 16:14:58

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @pulses_OpeningFcn, ...
                   'gui_OutputFcn',  @pulses_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes on button press in start.
function start_Callback(hObject, eventdata, handles)
% hObject    handle to start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% autofocus;
clc
         
if getV(handles.rabi)
    rabi_power_sweep = 0;
    if rabi_power_sweep 
%         for frequency = getN(handles.NV_rf)
%             setN(handles.NV_rf, frequency);
            powers = [0: -2: -20];
            disp('doing a rabi oscillation for many RF powers');
            for power = powers
%                 autofocus;
                disp(['rf power = ' num2str(power) ' dBm'])
                file_name = ['rabi_sweep_' num2str(power) 'dBm_rf.mat'];
                setN(handles.NV_power, power)
                rabi(handles, file_name);          
            end
            disp('power sweep done')
%         end
    else    
        autofocus;
        rabi(handles);
    end
elseif getV(handles.ramsey)
    NVfreq1 = getN(handles.NV_rf);
    NVfreq2 = getN(handles.NV_rf_2);
    ramsey_sweep = 0;
    format long
    if ramsey_sweep
        
        freq_step = -200;
        freq_range= -2000;
        NVfreq1_array = NVfreq1*10^6: freq_step : NVfreq1*10^6 + freq_range;
        NVfreq2_array = NVfreq2*10^6: -freq_step : NVfreq2*10^6 - freq_range;
        
        for f = 1:length(NVfreq1_array)            
            setN(handles.NV_rf,     NVfreq1_array(f));
            setN(handles.NV_rf_2,   NVfreq2_array(f));
            ramsey(handles, ['ramsey_DQ_' num2str(f) '.mat'])
        end
        
        setN(handles.NV_rf,     NVfreq1); 
        setN(handles.NV_rf_2,     NVfreq2);
    
    else
%         autofocus;
        ramsey(handles);
    end
elseif getV(handles.spin_echo)
    autofocus;
    spinecho(handles);
elseif getV(handles.deer)
       deer_sweep = 1;
    if deer_sweep
            step = getN(handles.bath_rf_step);
            bath_start = input('enter bath rf start (MHz)')
            bath_end   = input('enter bath rf end (MHz)')
            bath_rfs   = bath_start:step:bath_end;
            num_freqs  = 100;
            num_sweeps = round(length(bath_rfs) / num_freqs);

            for sweep = 1:num_sweeps
                start_index = (sweep-1)*num_freqs + 1;
                freq_start  = bath_rfs(start_index);
                end_index   = (sweep-1)*num_freqs - 1 + num_freqs;
                freq_end    = bath_rfs(end_index);
                
                setN(handles.bath_rf_start, freq_start);
                setN(handles.bath_rf_end, freq_end);

                file_name = ['deersweep' num2str(sweep) '_' num2str(freq_start) 'to' num2str(freq_end) 'MHz.mat']
                autofocus;
                deer(handles, file_name);            
            end        
    else
        deer(handles);
    end
else
    fluorescence_saturation = 1;
    if fluorescence_saturation
        num_powers = 20;
        for p = 1:num_powers
            laser_on;
            power = input('enter optical power in mW: ');
            laser_off;
            if  power > 0
                file_name = ['pl_' num2str(power) 'mW'];
                input('please move mirror in front of sample then hit enter');
                autofocus;
                pl_saturation(handles, power, file_name);
            end
        end
    else
        error('please select an experiment!')
    end
    
end
disp('done')

% --- Executes just before pulses is made visible.
function pulses_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to pulses (see VARARGIN)

% Choose default command line output for pulses
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes pulses wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = pulses_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in rabi.
function rabi_Callback(hObject, eventdata, handles)
% hObject    handle to rabi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of rabi


% --- Executes on button press in ramsey.
function ramsey_Callback(hObject, eventdata, handles)
% hObject    handle to ramsey (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ramsey


% --- Executes on button press in spin_echo.
function spin_echo_Callback(hObject, eventdata, handles)
% hObject    handle to spin_echo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of spin_echo


% --- Executes on button press in deer.
function deer_Callback(hObject, eventdata, handles)
% hObject    handle to deer (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of deer





function exp_time_Callback(hObject, eventdata, handles)
% hObject    handle to exp_time (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of exp_time as text
%        str2double(get(hObject,'String')) returns contents of exp_time as a double


% --- Executes during object creation, after setting all properties.
function exp_time_CreateFcn(hObject, eventdata, handles)
% hObject    handle to exp_time (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function image_size_Callback(hObject, eventdata, handles)
% hObject    handle to image_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of image_size as text
%        str2double(get(hObject,'String')) returns contents of image_size as a double


% --- Executes during object creation, after setting all properties.
function image_size_CreateFcn(hObject, eventdata, handles)
% hObject    handle to image_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function binning_Callback(hObject, eventdata, handles)
% hObject    handle to binning (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of binning as text
%        str2double(get(hObject,'String')) returns contents of binning as a double


% --- Executes during object creation, after setting all properties.
function binning_CreateFcn(hObject, eventdata, handles)
% hObject    handle to binning (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function t_laser_Callback(hObject, eventdata, handles)
% hObject    handle to t_laser (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of t_laser as text
%        str2double(get(hObject,'String')) returns contents of t_laser as a double


% --- Executes during object creation, after setting all properties.
function t_laser_CreateFcn(hObject, eventdata, handles)
% hObject    handle to t_laser (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function t_rf_Callback(hObject, eventdata, handles)
% hObject    handle to t_rf (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of t_rf as text
%        str2double(get(hObject,'String')) returns contents of t_rf as a double


% --- Executes during object creation, after setting all properties.
function t_rf_CreateFcn(hObject, eventdata, handles)
% hObject    handle to t_rf (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function t_rf_start_Callback(hObject, eventdata, handles)
% hObject    handle to t_rf_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of t_rf_start as text
%        str2double(get(hObject,'String')) returns contents of t_rf_start as a double


% --- Executes during object creation, after setting all properties.
function t_rf_start_CreateFcn(hObject, eventdata, handles)
% hObject    handle to t_rf_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function t_rf_end_Callback(hObject, eventdata, handles)
% hObject    handle to t_rf_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of t_rf_end as text
%        str2double(get(hObject,'String')) returns contents of t_rf_end as a double


% --- Executes during object creation, after setting all properties.
function t_rf_end_CreateFcn(hObject, eventdata, handles)
% hObject    handle to t_rf_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function t_rf_step_Callback(hObject, eventdata, handles)
% hObject    handle to t_rf_step (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of t_rf_step as text
%        str2double(get(hObject,'String')) returns contents of t_rf_step as a double


% --- Executes during object creation, after setting all properties.
function t_rf_step_CreateFcn(hObject, eventdata, handles)
% hObject    handle to t_rf_step (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function bath_power_Callback(hObject, eventdata, handles)
% hObject    handle to bath_power (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of bath_power as text
%        str2double(get(hObject,'String')) returns contents of bath_power as a double


% --- Executes during object creation, after setting all properties.
function bath_power_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bath_power (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function tau_Callback(hObject, eventdata, handles)
% hObject    handle to tau (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of tau as text
%        str2double(get(hObject,'String')) returns contents of tau as a double


% --- Executes during object creation, after setting all properties.
function tau_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tau (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function NV_power_Callback(hObject, eventdata, handles)
% hObject    handle to NV_power (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of NV_power as text
%        str2double(get(hObject,'String')) returns contents of NV_power as a double


% --- Executes during object creation, after setting all properties.
function NV_power_CreateFcn(hObject, eventdata, handles)
% hObject    handle to NV_power (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function bath_t_rf_Callback(hObject, eventdata, handles)
% hObject    handle to bath_t_rf (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of bath_t_rf as text
%        str2double(get(hObject,'String')) returns contents of bath_t_rf as a double


% --- Executes during object creation, after setting all properties.
function bath_t_rf_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bath_t_rf (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function tau_start_Callback(hObject, eventdata, handles)
% hObject    handle to tau_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of tau_start as text
%        str2double(get(hObject,'String')) returns contents of tau_start as a double


% --- Executes during object creation, after setting all properties.
function tau_start_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tau_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function tau_end_Callback(hObject, eventdata, handles)
% hObject    handle to tau_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of tau_end as text
%        str2double(get(hObject,'String')) returns contents of tau_end as a double


% --- Executes during object creation, after setting all properties.
function tau_end_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tau_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function tau_step_Callback(hObject, eventdata, handles)
% hObject    handle to tau_step (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of tau_step as text
%        str2double(get(hObject,'String')) returns contents of tau_step as a double


% --- Executes during object creation, after setting all properties.
function tau_step_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tau_step (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function NV_rf_Callback(hObject, eventdata, handles)
% hObject    handle to NV_rf (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of NV_rf as text
%        str2double(get(hObject,'String')) returns contents of NV_rf as a double


% --- Executes during object creation, after setting all properties.
function NV_rf_CreateFcn(hObject, eventdata, handles)
% hObject    handle to NV_rf (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in abort.
function abort_Callback(hObject, eventdata, handles)
% hObject    handle to abort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of abort



function bath_rf_start_Callback(hObject, eventdata, handles)
% hObject    handle to bath_rf_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of bath_rf_start as text
%        str2double(get(hObject,'String')) returns contents of bath_rf_start as a double


% --- Executes during object creation, after setting all properties.
function bath_rf_start_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bath_rf_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function bath_rf_step_Callback(hObject, eventdata, handles)
% hObject    handle to bath_rf_step (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of bath_rf_step as text
%        str2double(get(hObject,'String')) returns contents of bath_rf_step as a double


% --- Executes during object creation, after setting all properties.
function bath_rf_step_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bath_rf_step (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function bath_rf_end_Callback(hObject, eventdata, handles)
% hObject    handle to bath_rf_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of bath_rf_end as text
%        str2double(get(hObject,'String')) returns contents of bath_rf_end as a double


% --- Executes during object creation, after setting all properties.
function bath_rf_end_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bath_rf_end (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function NV_rf_2_Callback(hObject, eventdata, handles)
% hObject    handle to NV_rf_2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of NV_rf_2 as text
%        str2double(get(hObject,'String')) returns contents of NV_rf_2 as a double


% --- Executes during object creation, after setting all properties.
function NV_rf_2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to NV_rf_2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function NV_rf_power_2_Callback(hObject, eventdata, handles)
% hObject    handle to NV_rf_power_2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of NV_rf_power_2 as text
%        str2double(get(hObject,'String')) returns contents of NV_rf_power_2 as a double


% --- Executes during object creation, after setting all properties.
function NV_rf_power_2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to NV_rf_power_2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ddq.
function ddq_Callback(hObject, eventdata, handles)
% hObject    handle to ddq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ddq


% --- Executes on button press in rhodeorhp.
function rhodeorhp_Callback(hObject, eventdata, handles)
% hObject    handle to rhodeorhp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of rhodeorhp
