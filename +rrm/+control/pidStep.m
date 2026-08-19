function [tau, nextState, diagnostic] = pidStep( ...
        controller, robot, qReference, dqReference, q, dq, state, sampleTime, ...
        effectiveGains)
%PIDSTEP Evaluate one torque-limited independent-joint PID update.
arguments
    controller (1,1) struct
    robot (1,1) struct
    qReference double {mustBeFinite, mustBeReal}
    dqReference double {mustBeFinite, mustBeReal}
    q double {mustBeFinite, mustBeReal}
    dq double {mustBeFinite, mustBeReal}
    state (1,1) struct
    sampleTime (1,1) double {mustBeFinite, mustBeReal, mustBePositive}
    effectiveGains (1,1) struct = struct()
end

mustBeTwoElementColumn(qReference, "qReference");
mustBeTwoElementColumn(dqReference, "dqReference");
mustBeTwoElementColumn(q, "q");
mustBeTwoElementColumn(dq, "dq");
mustBeTwoElementColumn(state.integral, "state.integral");
mustBeTwoElementColumn( ...
    state.filteredDerivative, "state.filteredDerivative");
effectiveGains = resolveGains(controller, effectiveGains);

errorValue = qReference - q;
rawDerivative = dqReference - dq;
filterAlpha = exp(-2*pi*controller.derivativeFilterHz*sampleTime);
filteredDerivative = filterAlpha*state.filteredDerivative + ...
    (1-filterAlpha)*rawDerivative;

unsaturatedTorque = effectiveGains.Kp.*errorValue + ...
    effectiveGains.Ki.*state.integral + ...
    effectiveGains.Kd.*filteredDerivative;
torqueLimit = min(controller.torqueLimits, robot.torqueLimits);
tau = max(-torqueLimit, min(torqueLimit, unsaturatedTorque));
saturated = abs(unsaturatedTorque - tau) > 100*eps(max(abs(tau), 1));

integralDerivative = errorValue + controller.antiWindupGain .* ...
    (tau - unsaturatedTorque);
nextState = struct( ...
    "integral", state.integral + sampleTime*integralDerivative, ...
    "filteredDerivative", filteredDerivative);
diagnostic = struct( ...
    "error", errorValue, ...
    "unsaturatedTorque", unsaturatedTorque, ...
    "saturated", saturated, ...
    "effectiveKp", effectiveGains.Kp, ...
    "effectiveKi", effectiveGains.Ki, ...
    "effectiveKd", effectiveGains.Kd);
end

function gains = resolveGains(controller, requestedGains)
gainNames = ["Kp", "Ki", "Kd"];
if isempty(fieldnames(requestedGains))
    gains = struct( ...
        "Kp", controller.Kp, ...
        "Ki", controller.Ki, ...
        "Kd", controller.Kd);
else
    if ~all(isfield(requestedGains, gainNames))
        error("rrm:control:InvalidGains", ...
            "Effective gains must define Kp, Ki, and Kd.");
    end
    gains = requestedGains;
end

for gainName = gainNames
    value = gains.(gainName);
    if ~isequal(size(value), [2 1]) || ...
            ~isreal(value) || any(~isfinite(value)) || any(value < 0)
        error("rrm:control:InvalidGains", ...
            "Every effective gain must be a finite nonnegative 2-by-1 vector.");
    end
end
end

function mustBeTwoElementColumn(value, name)
if ~isequal(size(value), [2 1])
    error("rrm:control:InvalidVector", ...
        "%s must be a 2-by-1 column vector.", name);
end
end
