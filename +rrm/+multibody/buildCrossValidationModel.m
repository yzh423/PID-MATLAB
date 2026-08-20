function modelName = buildCrossValidationModel(modelPath)
%BUILDCROSSVALIDATIONMODEL Build the Multibody validation model.
arguments
    modelPath (1,1) string
end

validateCapability();
modelPath = resolveModelPath(modelPath);
[~,name] = fileparts(modelPath);
modelName = string(name);
sourcePath = fullfile(projectRoot(),"models", ...
    "rrm_pid_cross_validation.slx");
if ~isfile(sourcePath)
    error("rrm:multibody:MissingSourceModel", ...
        "The verified Phase 6A source model is required.");
end

closeIfLoaded(modelName);
if isfile(modelPath)
    delete(modelPath);
end

sourceName = "rrm_pid_cross_validation";
sourceWasLoaded = bdIsLoaded(sourceName);
load_system(sourcePath);
sourceCleanup = onCleanup(@() closeSource(sourceName,sourceWasLoaded));
new_system(modelName);
try
set_param(modelName, ...
    "SolverType","Fixed-step", ...
    "Solver","ode4", ...
    "FixedStep","0.001", ...
    "StopTime","rrmStopTime", ...
    "SignalLogging","on", ...
    "ReturnWorkspaceOutputs","on");

add_block(sourceName + "/Reference",modelName + "/Reference", ...
    "Position",[30 80 230 280]);
add_block(sourceName + "/PID Controller", ...
    modelName + "/PID Controller", ...
    "Position",[350 40 650 320]);
add_block("simulink/Ports & Subsystems/Subsystem", ...
    modelName + "/Multibody Plant", ...
    "Position",[790 40 1070 320]);
add_block("simulink/Ports & Subsystems/Subsystem", ...
    modelName + "/Logging", ...
    "Position",[1200 70 1420 290]);
assignDefaults(modelName);
annotation = Simulink.Annotation(modelName, ...
    "Phase 6B torque-driven Simscape Multibody validation" + newline + ...
    "q [rad], dq [rad/s], tau [N m], end-effector position [m]");
annotation.Position = [410 370 1010 420];
save_system(modelName,modelPath);
catch exception
    closeIfLoaded(modelName);
    rethrow(exception);
end
clear sourceCleanup
end

function validateCapability()
if isempty(which("smnew")) || isempty(which("sm_lib")) || ...
        ~license("test","SimMechanics")
    error("rrm:multibody:MissingMultibody", ...
        "Simscape Multibody must be installed and licensed.");
end
end

function modelPath = resolveModelPath(modelPath)
if ~java.io.File(char(modelPath)).isAbsolute()
    modelPath = fullfile(projectRoot(),modelPath);
end
[parent,name,extension] = fileparts(modelPath);
if ~strcmpi(extension,".slx") || strlength(name) == 0 || ...
        ~isvarname(name)
    error("rrm:multibody:InvalidModelPath", ...
        "Model path must name a valid .slx file.");
end
if strlength(parent) == 0
    parent = ".";
end
if ~isfolder(parent)
    [created,message] = mkdir(parent);
    if ~created
        error("rrm:multibody:InvalidModelPath", ...
            "Unable to create model directory: %s",message);
    end
end
parent = string(java.io.File(char(parent)).getCanonicalPath());
modelPath = fullfile(parent,name + extension);
end

function root = projectRoot()
functionPath = mfilename("fullpath");
root = string(fileparts(fileparts(fileparts(functionPath))));
end

function assignDefaults(modelName)
robot = rrm.config.makeRobot("baseline");
controller = rrm.config.makePidController(robot);
sampleTime = 0.001;
reference = rrm.trajectory.quintic( ...
    [0;0],deg2rad([5;8]),0.02,sampleTime,0.03);
workspace = get_param(modelName,"ModelWorkspace");
assignin(workspace,"rrmSampleTime",sampleTime);
assignin(workspace,"rrmStopTime",reference.time(end));
assignin(workspace,"rrmQReferenceSignal", ...
    timeseries(reference.q.',reference.time));
assignin(workspace,"rrmDqReferenceSignal", ...
    timeseries(reference.dq.',reference.time));
assignin(workspace,"rrmKp",controller.Kp);
assignin(workspace,"rrmKi",controller.Ki);
assignin(workspace,"rrmKd",controller.Kd);
assignin(workspace,"rrmDerivativeAlpha", ...
    exp(-2*pi*controller.derivativeFilterHz*sampleTime));
assignin(workspace,"rrmAntiWindupGain",controller.antiWindupGain);
assignin(workspace,"rrmTorqueLimits",robot.torqueLimits);
assignin(workspace,"rrmInitialQ",reference.q(:,1));
assignin(workspace,"rrmInitialDq",zeros(2,1));
end

function closeSource(modelName,wasLoaded)
if ~wasLoaded
    closeIfLoaded(modelName);
end
end

function closeIfLoaded(modelName)
if bdIsLoaded(modelName)
    close_system(modelName,0);
end
end
