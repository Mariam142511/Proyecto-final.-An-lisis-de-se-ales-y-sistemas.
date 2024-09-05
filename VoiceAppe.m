classdef VoiceAppe < matlab.apps.AppBase

    % Properties que corresponden a los componentes de la interfaz
    properties (Access = public)
        UIFigure                  matlab.ui.Figure
        TitleLabel                matlab.ui.control.Label
        InstructionsLabel         matlab.ui.control.Label
        RecordButton              matlab.ui.control.Button
        ClassifyButton            matlab.ui.control.Button
        ResultLabel               matlab.ui.control.Label
    end
    
    properties (Access = private)
        RecordedAudio % Variable para guardar el audio grabado
        SampleRate % Frecuencia de muestreo para la grabación
        Model % Variable para el modelo de reconocimiento
    end
    
    % Variables globales para almacenar los datos
    properties (Access = private)
        audioIn % Variable para almacenar el audio grabado
        fs = 8000;  % Frecuencia de muestreo
        nBits = 16;  % Resolución en bits
        duration = 2;  % Duración de la grabación
        energyThreshold = 0.35;
        zcrThreshold = 0.22;
        trainedClassifier % Clasificador entrenado
        M % Media de las características para normalización
        S % Desviación estándar para normalización
    end
    
    methods (Access = private)
        % Función para cargar el clasificador entrenado y los datos de normalización
        function loadModel(app)
            % Cargar el clasificador entrenado, M y S
            load("C:\Users\alfre\OneDrive\Documentos\MATLAB\Convulacion\modeloEntrenado.mat", 'trainedClassifier', 'M', 'S');
            app.trainedClassifier = trainedClassifier;
            
            app.M = M;
            app.S = S;
        end

        % Callback function: RecordButton
        function RecordButtonPushed(app, event)
            % Limpiar la etiqueta de resultado
            app.ResultLabel.Text = ''; % Vaciar el resultado anterior

            % Crear el objeto audiorecorder con la frecuencia de muestreo almacenada
            app.RecordedAudio = audiorecorder; % 16 bits y 

            % Iniciar la grabación por 2 segundos
            disp('Grabando ...');
            recordblocking(app.RecordedAudio, app.duration); % Graba por la duración especificada
            disp('Fin de la grabación.');

            % Obtener el audio grabado
            app.audioIn = mean(getaudiodata(app.RecordedAudio), 2); % Convertir a mono promediando los dos canales
 % Obtener los datos de la grabación

            % Reproducir el audio grabado
            sound(app.audioIn, app.fs); % Reproducir el audio grabado
            disp('Reproduciendo el audio grabado.');
        end

        % Función para mostrar un mensaje cuando no se pueden extraer datos
        function noSePudieronExtraerDatos(app)
            uialert(app.UIFigure, 'No se pudieron extraer datos del audio. Intenta de nuevo.', 'Error de extracción');
        end

        % Función para mostrar un mensaje cuando no se reconoce a la persona
        function noSeReconocioPersona(app)
            uialert(app.UIFigure, 'No se reconoció a la persona. Intenta de nuevo.', 'Error de reconocimiento');
        end

        % Función para predecir la voz
        function ClassifyButtonPushed(app, event)
            % Verifica si el audio ha sido grabado
            if isempty(app.audioIn)
                disp('Error: No se ha grabado ningún audio.');
                return;
            end


            % Definir los parámetros de la ventana
            features = [];
            windowLength = round(0.03 * app.fs);   % Largo de ventana (30 ms)
            overlapLength = round(0.025 * app.fs); % Solapamiento (25 ms)

            % Crear un extractor de características similar al usado en el entrenamiento
            afe = audioFeatureExtractor('SampleRate', app.fs, ...
                'Window', hamming(windowLength, "periodic"), ...
                'OverlapLength', overlapLength, ...
                'zerocrossrate', true, ...
                'shortTimeEnergy', true, ...
                'pitch', true, ...
                'mfcc', true);
            
           
            pruebaB = app.audioIn;
            % Extraer las características del audio grabado
            inputFeatures = extract(afe, pruebaB);
            featureMap = info(afe);
            
            % Filtrar las características de voz
            isSpeech = inputFeatures(:, featureMap.shortTimeEnergy) > app.energyThreshold;
            isVoiced = inputFeatures(:, featureMap.zerocrossrate) < app.zcrThreshold;
            voicedSpeech = isSpeech & isVoiced
            
            % Filtrar las características no necesarias
            inputFeatures(~voicedSpeech, :) = [];
            inputFeatures(:, [featureMap.zerocrossrate, featureMap.shortTimeEnergy]) = [];

            features = [features; inputFeatures];

            features = (features - app.M) ./ app.S;

            prediction = predict(app.trainedClassifier, features);
            prediction = mode(prediction);



            % Mostrar el resultado final en la interfaz
        if isempty(features)
       noSePudieronExtraerDatos(app);
         return;
        end

        if strcmp(prediction, 'Desconocido')
        noSeReconocioPersona(app);
        else
     app.ResultLabel.Text = ['Voz de ', prediction];
        end


  


        end
    end

    % Component initialization
    methods (Access = private)

        % Crear componentes de la interfaz
        function createComponents(app)

            % Crear la ventana UIFigure y ocultarla hasta que se creen todos los componentes
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 400 300];
            app.UIFigure.Name = 'Voice Recognition';
            app.UIFigure.Color = [1 1 1]; % Cambiar el color de fondo a blanco

            % Crear TitleLabel
            app.TitleLabel = uilabel(app.UIFigure);
            app.TitleLabel.HorizontalAlignment = 'center';
            app.TitleLabel.FontSize = 20;
            app.TitleLabel.FontWeight = 'bold'; % Poner en negritas
            app.TitleLabel.Position = [50 240 300 40];
            app.TitleLabel.Text = 'Reconocimiento de Voz';

            % Crear InstructionsLabel
            app.InstructionsLabel = uilabel(app.UIFigure);
            app.InstructionsLabel.HorizontalAlignment = 'center';
            app.InstructionsLabel.FontSize = 14;
            app.InstructionsLabel.FontAngle = 'italic'; % Poner el texto en cursiva
            app.InstructionsLabel.Position = [50 200 300 40];
            app.InstructionsLabel.Text = 'Al pulsar el botón de grabar, di "Oye Nova"';

            % Crear RecordButton
            app.RecordButton = uibutton(app.UIFigure, 'push');
            app.RecordButton.ButtonPushedFcn = createCallbackFcn(app, @RecordButtonPushed, true);
            app.RecordButton.Position = [70 120 90 70]; % Ajustar el tamaño del botón
            app.RecordButton.Text = ''; % Eliminar el texto si solo quieres la imagen
            app.RecordButton.Icon = 'C:\Users\yestl\OneDrive\Escritorio\MATLAB\proyecto\Microfono.png'; % Asignar la imagen al botón

            % Crear ClassifyButton
            app.ClassifyButton = uibutton(app.UIFigure, 'push');
            app.ClassifyButton.ButtonPushedFcn = createCallbackFcn(app, @ClassifyButtonPushed, true);
            app.ClassifyButton.Position = [250 120 90 70]; % Ajustar el tamaño del botón
            app.ClassifyButton.Text = ''; % Eliminar el texto
            app.ClassifyButton.Icon = 'C:\Users\yestl\OneDrive\Escritorio\MATLAB\proyecto\Clasificar.png'; % Asignar la imagen circular al botón de clasificar

            % Crear ResultLabel (Inicialmente vacío)
            app.ResultLabel = uilabel(app.UIFigure);
            app.ResultLabel.HorizontalAlignment = 'center';
            app.ResultLabel.FontSize = 14;
            app.ResultLabel.Position = [100 50 200 40]; % Cambiar la posición aquí
            app.ResultLabel.Text = ''; % Inicialmente vacío hasta que se pulse el botón de clasificar

            % Mostrar la ventana después de crear todos los componentes
            app.UIFigure.Visible = 'on';
        end
    end

    % Inicialización de la aplicación
    methods (Access = public)

        % Construct app
        function app = VoiceAppe
            % Cargar el modelo entrenado
            loadModel(app);
            % Crear y configurar los componentes
            createComponents(app)
        end
    end
end