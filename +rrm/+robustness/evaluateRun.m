function metrics = evaluateRun(result, robot, criteria, scenario)
%EVALUATERUN Calculate joint, Cartesian, saturation, and recovery metrics.
arguments
    result (1,1) struct
    robot (1,1) struct
    criteria (1,1) struct
    scenario (1,1) struct
end

common = rrm.metrics.evaluate(result, criteria);
valid = all(isfinite(result.q), 1) & ...
    all(isfinite(result.qReference), 1);
q = result.q(:,valid);
qReference = result.qReference(:,valid);

actualPosition = planarPosition(robot, q);
referencePosition = planarPosition(robot, qReference);
positionError = sqrt(sum((referencePosition - actualPosition).^2, 1));
endEffectorRmsError = sqrt(mean(positionError.^2));
endEffectorMaxError = max(positionError);
totalSaturationTime = sum(common.saturationTime);
recoveryTime = calculateRecovery(result, scenario);

metrics = struct( ...
    "common", common, ...
    "endEffectorRmsError", endEffectorRmsError, ...
    "endEffectorMaxError", endEffectorMaxError, ...
    "totalSaturationTime", totalSaturationTime, ...
    "recoveryTime", recoveryTime, ...
    "success", common.success && endEffectorMaxError <= 0.15);
end

function position = planarPosition(robot, q)
q12 = q(1,:) + q(2,:);
position = [ ...
    robot.L1*cos(q(1,:)) + robot.L2*cos(q12); ...
    robot.L1*sin(q(1,:)) + robot.L2*sin(q12)];
end

function recoveryTime = calculateRecovery(result, scenario)
window = scenario.disturbanceWindow;
if any(isnan(window))
    recoveryTime = NaN;
    return
end

time = result.time(:);
if numel(time) < 2
    recoveryTime = Inf;
    return
end
errorValue = abs(result.qReference - result.q);
withinBand = all(isfinite(errorValue), 1) & ...
    all(errorValue <= scenario.recoveryBand, 1);
sampleTime = median(diff(time));
windowSamples = ceil(scenario.recoveryDwell / sampleTime) + 1;
firstCandidate = find(time >= window(2), 1, "first");
lastStart = numel(time) - windowSamples + 1;

recoveryTime = Inf;
if isempty(firstCandidate) || firstCandidate > lastStart
    return
end
for sample = firstCandidate:lastStart
    if all(withinBand(sample:sample+windowSamples-1)) && ...
            time(sample+windowSamples-1) - time(sample) + ...
            100*eps(max(time(end),1)) >= scenario.recoveryDwell
        recoveryTime = time(sample) - window(2);
        return
    end
end
end
