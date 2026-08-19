function result = runController(robot, controller, reference, options)
%RUNCONTROLLER Simulate a supported controller with fixed-step RK4.
arguments
    robot (1,1) struct
    controller (1,1) struct
    reference (1,1) struct
    options (1,1) struct
end

validateControllerType(controller);
validateReference(reference, options.sampleTime);
sampleCount = numel(reference.time);
disturbanceTorque = expandDisturbance( ...
    options.disturbanceTorque, sampleCount);
q = NaN(2, sampleCount);
dq = NaN(2, sampleCount);
tau = NaN(2, sampleCount);
tauUnsaturated = NaN(2, sampleCount);
saturated = false(2, sampleCount);
effectiveKp = NaN(2, sampleCount);
effectiveKi = NaN(2, sampleCount);
effectiveKd = NaN(2, sampleCount);
normalizedError = NaN(2, sampleCount);
normalizedRate = NaN(2, sampleCount);
fuzzyCorrection = NaN(3, 2, sampleCount);
q(:,1) = reference.q(:,1);
dq(:,1) = options.initialVelocity;

controllerState = struct( ...
    "integral", [0; 0], ...
    "filteredDerivative", [0; 0]);
status = "completed";
completedSamples = sampleCount;

for sample = 1:sampleCount
    [tau(:,sample), controllerState, diagnostic] = controllerStep( ...
        controller, robot, reference.q(:,sample), ...
        reference.dq(:,sample), q(:,sample), dq(:,sample), ...
        controllerState, options.sampleTime);
    tauUnsaturated(:,sample) = diagnostic.unsaturatedTorque;
    saturated(:,sample) = diagnostic.saturated;
    effectiveKp(:,sample) = diagnostic.effectiveKp;
    effectiveKi(:,sample) = diagnostic.effectiveKi;
    effectiveKd(:,sample) = diagnostic.effectiveKd;
    if isfield(diagnostic, "fuzzyCorrection")
        normalizedError(:,sample) = diagnostic.normalizedError;
        normalizedRate(:,sample) = diagnostic.normalizedRate;
        fuzzyCorrection(:,:,sample) = diagnostic.fuzzyCorrection;
    end

    if sample == sampleCount
        break
    end

    state = [q(:,sample); dq(:,sample)];
    nextState = rk4Step( ...
        robot, state, tau(:,sample), ...
        disturbanceTorque(:,sample), options.sampleTime);
    q(:,sample+1) = nextState(1:2);
    dq(:,sample+1) = nextState(3:4);

    if any(~isfinite(nextState))
        status = "non-finite-state";
        completedSamples = sample;
        break
    end
    if any(q(:,sample+1) < robot.jointLimits(:,1)) || ...
            any(q(:,sample+1) > robot.jointLimits(:,2))
        status = "joint-limit-violation";
        completedSamples = sample + 1;
        break
    end
end

result = struct( ...
    "time", reference.time, ...
    "q", q, ...
    "dq", dq, ...
    "qReference", reference.q, ...
    "dqReference", reference.dq, ...
    "tau", tau, ...
    "tauUnsaturated", tauUnsaturated, ...
    "saturated", saturated, ...
    "effectiveKp", effectiveKp, ...
    "effectiveKi", effectiveKi, ...
    "effectiveKd", effectiveKd, ...
    "normalizedError", normalizedError, ...
    "normalizedRate", normalizedRate, ...
    "fuzzyCorrection", fuzzyCorrection, ...
    "disturbanceTorque", disturbanceTorque, ...
    "status", status, ...
    "completedSamples", completedSamples);
end

function history = expandDisturbance(disturbance, sampleCount)
isValidValues = isnumeric(disturbance) && isreal(disturbance) && ...
    all(isfinite(disturbance), "all");
if ~isValidValues || ...
        ~(isequal(size(disturbance), [2 1]) || ...
        isequal(size(disturbance), [2 sampleCount]))
    error("rrm:simulation:InvalidDisturbance", ...
        "Disturbance torque must be finite real 2-by-1 or 2-by-N data.");
end
if size(disturbance, 2) == 1
    history = repmat(disturbance, 1, sampleCount);
else
    history = disturbance;
end
end

function [tau, nextState, diagnostic] = controllerStep( ...
        controller, robot, qReference, dqReference, q, dq, state, sampleTime)
switch controller.type
    case "pid"
        [tau, nextState, diagnostic] = rrm.control.pidStep( ...
            controller, robot, qReference, dqReference, q, dq, ...
            state, sampleTime);
    case "fuzzy-pid"
        [tau, nextState, diagnostic] = rrm.control.fuzzyPidStep( ...
            controller, robot, qReference, dqReference, q, dq, ...
            state, sampleTime);
end
end

function validateControllerType(controller)
if ~isfield(controller, "type") || ...
        ~any(controller.type == ["pid", "fuzzy-pid"])
    error("rrm:simulation:UnknownControllerType", ...
        "Controller type must be pid or fuzzy-pid.");
end
end

function nextState = rk4Step(robot, state, tau, disturbance, sampleTime)
derivative = @(x) plantDerivative(robot, x, tau, disturbance);
k1 = derivative(state);
k2 = derivative(state + 0.5*sampleTime*k1);
k3 = derivative(state + 0.5*sampleTime*k2);
k4 = derivative(state + sampleTime*k3);
nextState = state + sampleTime*(k1 + 2*k2 + 2*k3 + k4) / 6;
end

function derivative = plantDerivative(robot, state, tau, disturbance)
q = state(1:2);
dq = state(3:4);
ddq = rrm.dynamics.acceleration(robot, q, dq, tau, disturbance);
derivative = [dq; ddq];
end

function validateReference(reference, sampleTime)
requiredFields = ["time", "q", "dq", "ddq"];
if ~all(isfield(reference, requiredFields))
    error("rrm:simulation:InvalidReference", ...
        "Reference is missing one or more required fields.");
end
sampleCount = numel(reference.time);
if ~isequal(size(reference.time), [sampleCount 1]) || ...
        ~isequal(size(reference.q), [2 sampleCount]) || ...
        ~isequal(size(reference.dq), [2 sampleCount]) || ...
        ~isequal(size(reference.ddq), [2 sampleCount])
    error("rrm:simulation:InvalidReference", ...
        "Reference arrays have inconsistent dimensions.");
end
timeSteps = diff(reference.time);
if any(timeSteps <= 0) || ...
        any(abs(timeSteps - sampleTime) > 100*eps(max(reference.time(end),1)))
    error("rrm:simulation:InvalidTimeGrid", ...
        "Reference time must be strictly increasing at the configured step.");
end
end
