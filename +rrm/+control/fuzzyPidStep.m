function [tau, nextState, diagnostic] = fuzzyPidStep( ...
        controller, robot, qReference, dqReference, q, dq, state, sampleTime)
%FUZZYPIDSTEP Evaluate one bounded Mamdani Fuzzy-PID update.
arguments
    controller (1,1) struct
    robot (1,1) struct
    qReference double {mustBeFinite, mustBeReal}
    dqReference double {mustBeFinite, mustBeReal}
    q double {mustBeFinite, mustBeReal}
    dq double {mustBeFinite, mustBeReal}
    state (1,1) struct
    sampleTime (1,1) double {mustBeFinite, mustBeReal, mustBePositive}
end

normalizedError = clampNormalized( ...
    (qReference-q)./controller.errorScale);
normalizedRate = clampNormalized( ...
    (dqReference-dq)./controller.errorRateScale);
fuzzyCorrection = zeros(3,2);
for joint = 1:2
    fuzzyCorrection(:,joint) = rrm.fuzzy.mamdani( ...
        controller, normalizedError(joint), normalizedRate(joint));
end

gains = struct( ...
    "Kp", boundedGain(controller, "Kp", fuzzyCorrection(1,:).'), ...
    "Ki", boundedGain(controller, "Ki", fuzzyCorrection(2,:).'), ...
    "Kd", boundedGain(controller, "Kd", fuzzyCorrection(3,:).'));
[tau, nextState, diagnostic] = rrm.control.pidStep( ...
    controller, robot, qReference, dqReference, q, dq, state, ...
    sampleTime, gains);
diagnostic.normalizedError = normalizedError;
diagnostic.normalizedRate = normalizedRate;
diagnostic.fuzzyCorrection = fuzzyCorrection;
end

function value = clampNormalized(value)
if ~isequal(size(value), [2 1])
    error("rrm:control:InvalidVector", ...
        "Fuzzy-PID inputs must be 2-by-1 column vectors.");
end
value = max(-1, min(1, value));
end

function gain = boundedGain(controller, gainName, correction)
gain = controller.(gainName).*(1 + ...
    controller.correctionFraction.(gainName).*correction);
gain = max(controller.gainBounds.lower.(gainName), ...
    min(controller.gainBounds.upper.(gainName), gain));
end
