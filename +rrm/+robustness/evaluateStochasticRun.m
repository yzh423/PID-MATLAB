function metrics = evaluateStochasticRun(result, robot, criteria, scenario)
%EVALUATESTOCHASTICRUN Add noise-sensitivity metrics to Phase 4A metrics.
arguments
    result (1,1) struct
    robot (1,1) struct
    criteria (1,1) struct
    scenario (1,1) struct
end

[valid, sampleTime] = validateResult(result);
robustness = rrm.robustness.evaluateRun( ...
    result,robot,criteria,scenario);
trackingError = result.qReference(:,valid) - result.q(:,valid);
torque = result.tau(:,valid);
trackingErrorVariance = var(trackingError,0,2);
torqueSlewRms = sqrt(mean((diff(torque,1,2)/sampleTime).^2,2));

metrics = struct( ...
    "robustness",robustness, ...
    "trackingErrorVariance",trackingErrorVariance, ...
    "torqueSlewRms",torqueSlewRms, ...
    "torqueSlewMean",mean(torqueSlewRms));
end

function [valid, sampleTime] = validateResult(result)
required = ["time","q","qReference","tau"];
if ~all(isfield(result,required))
    error("rrm:robustness:InvalidStochasticResult", ...
        "Stochastic result is missing required histories.");
end
sampleCount = numel(result.time);
if ~isequal(size(result.time),[sampleCount 1]) || ...
        ~isequal(size(result.q),[2 sampleCount]) || ...
        ~isequal(size(result.qReference),[2 sampleCount]) || ...
        ~isequal(size(result.tau),[2 sampleCount])
    error("rrm:robustness:InvalidStochasticResult", ...
        "Stochastic result histories have inconsistent sizes.");
end
valid = all(isfinite(result.q),1) & ...
    all(isfinite(result.qReference),1) & all(isfinite(result.tau),1);
if nnz(valid) < 2
    error("rrm:robustness:InvalidStochasticResult", ...
        "At least two finite result samples are required.");
end
time = result.time(valid);
steps = diff(time);
sampleTime = steps(1);
tolerance = 100*eps(max(abs(time(end)),1));
if any(~isfinite(time)) || sampleTime <= 0 || ...
        any(abs(steps-sampleTime) > tolerance)
    error("rrm:robustness:InvalidStochasticResult", ...
        "Finite result samples must use a uniform increasing time grid.");
end
end
