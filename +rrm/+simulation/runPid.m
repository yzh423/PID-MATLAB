function result = runPid(robot, controller, reference, options)
%RUNPID Simulate the closed-loop two-link robot with fixed-step RK4.
arguments
    robot (1,1) struct
    controller (1,1) struct
    reference (1,1) struct
    options (1,1) struct
end

validateReference(reference, options.sampleTime);
sampleCount = numel(reference.time);
q = NaN(2, sampleCount);
dq = NaN(2, sampleCount);
tau = NaN(2, sampleCount);
tauUnsaturated = NaN(2, sampleCount);
saturated = false(2, sampleCount);
q(:,1) = reference.q(:,1);
dq(:,1) = options.initialVelocity;

controllerState = struct( ...
    "integral", [0; 0], ...
    "filteredDerivative", [0; 0]);
status = "completed";
completedSamples = sampleCount;

for sample = 1:sampleCount
    [tau(:,sample), controllerState, diagnostic] = ...
        rrm.control.pidStep( ...
            controller, robot, reference.q(:,sample), ...
            reference.dq(:,sample), q(:,sample), dq(:,sample), ...
            controllerState, options.sampleTime);
    tauUnsaturated(:,sample) = diagnostic.unsaturatedTorque;
    saturated(:,sample) = diagnostic.saturated;

    if sample == sampleCount
        break
    end

    state = [q(:,sample); dq(:,sample)];
    nextState = rk4Step( ...
        robot, state, tau(:,sample), ...
        options.disturbanceTorque, options.sampleTime);
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
    "status", status, ...
    "completedSamples", completedSamples);
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
