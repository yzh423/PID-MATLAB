function reference = quintic(q0, qf, moveDuration, sampleTime, totalDuration)
%QUINTIC Generate a rest-to-rest joint trajectory with a terminal hold.
arguments
    q0 double {mustBeFinite, mustBeReal}
    qf double {mustBeFinite, mustBeReal}
    moveDuration (1,1) double {mustBeFinite, mustBeReal, mustBePositive}
    sampleTime (1,1) double {mustBeFinite, mustBeReal, mustBePositive}
    totalDuration (1,1) double {mustBeFinite, mustBeReal, mustBePositive} = moveDuration
end

mustBeTwoElementColumn(q0, "q0");
mustBeTwoElementColumn(qf, "qf");
if totalDuration < moveDuration
    error("rrm:trajectory:InvalidDuration", ...
        "Total duration must be at least the motion duration.");
end

stepCount = round(totalDuration / sampleTime);
if abs(stepCount*sampleTime - totalDuration) > ...
        100*eps(max(totalDuration, 1))
    error("rrm:trajectory:InvalidSampleGrid", ...
        "Total duration must be an integer multiple of sample time.");
end

time = (0:stepCount).' * sampleTime;
normalizedTime = min(time / moveDuration, 1);
s = 10*normalizedTime.^3 - 15*normalizedTime.^4 + ...
    6*normalizedTime.^5;
ds = (30*normalizedTime.^2 - 60*normalizedTime.^3 + ...
    30*normalizedTime.^4) / moveDuration;
dds = (60*normalizedTime - 180*normalizedTime.^2 + ...
    120*normalizedTime.^3) / moveDuration^2;

delta = qf - q0;
reference = struct( ...
    "time", time, ...
    "q", q0 + delta*s.', ...
    "dq", delta*ds.', ...
    "ddq", delta*dds.');
end

function mustBeTwoElementColumn(value, name)
if ~isequal(size(value), [2 1])
    error("rrm:trajectory:InvalidVector", ...
        "%s must be a 2-by-1 column vector.", name);
end
end
