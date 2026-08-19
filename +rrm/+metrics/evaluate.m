function metrics = evaluate(result, criteria)
%EVALUATE Calculate common trajectory-tracking and actuator metrics.
arguments
    result (1,1) struct
    criteria (1,1) struct
end

validSamples = all(isfinite(result.q), 1) & ...
    all(isfinite(result.qReference), 1) & all(isfinite(result.tau), 1);
if ~any(validSamples)
    error("rrm:metrics:NoValidSamples", ...
        "Result does not contain any finite samples.");
end

time = result.time(validSamples);
q = result.q(:,validSamples);
qReference = result.qReference(:,validSamples);
tau = result.tau(:,validSamples);
saturated = result.saturated(:,validSamples);
errorValue = qReference - q;

steadyStart = time(end) - criteria.steadyStateWindow;
steadySamples = time >= steadyStart;
steadyError = errorValue(:,steadySamples);

rmsError = sqrt(mean(errorValue.^2, 2));
maxAbsError = max(abs(errorValue), [], 2);
steadyStateRmsError = sqrt(mean(steadyError.^2, 2));
steadyStateMaxAbsError = max(abs(steadyError), [], 2);
controlRms = sqrt(mean(tau.^2, 2));
controlEnergy = trapz(time, sum(tau.^2, 1));
saturationTime = trapz(time, double(saturated), 2);

success = result.status == "completed" && ...
    all(steadyStateRmsError <= criteria.steadyStateRmsError) && ...
    all(steadyStateMaxAbsError <= criteria.steadyStateMaxAbsError);

metrics = struct( ...
    "rmsError", rmsError, ...
    "maxAbsError", maxAbsError, ...
    "steadyStateRmsError", steadyStateRmsError, ...
    "steadyStateMaxAbsError", steadyStateMaxAbsError, ...
    "controlRms", controlRms, ...
    "controlEnergy", controlEnergy, ...
    "saturationTime", saturationTime, ...
    "success", success);
end
