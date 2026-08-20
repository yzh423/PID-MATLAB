function metrics = evaluateCartesianTask( ...
        result,robot,reference,evaluationIndices)
%EVALUATECARTESIANTASK Calculate task-space execution metrics.
arguments
    result (1,1) struct
    robot (1,1) struct
    reference (1,1) struct
    evaluationIndices (1,1) struct = struct()
end

validateInputs(result,robot,reference,evaluationIndices);
criteria = rrm.config.makeSimulationOptions().successCriteria;
common = rrm.metrics.evaluate(result,criteria);
sampleCount = numel(reference.time);
desiredPosition = reference.cartesian.position;
actualPosition = NaN(2,sampleCount);
validSamples = all(isfinite(result.q),1);
for sample = find(validSamples)
    actualPosition(:,sample) = rrm.kinematics.forward( ...
        robot,result.q(:,sample));
end
cartesianError = vecnorm(desiredPosition-actualPosition,2,1);
finiteError = isfinite(cartesianError);
if ~any(finiteError)
    error("rrm:metrics:InvalidCartesianTaskInput", ...
        "Cartesian task result has no finite position samples.");
end
cartesianRms = sqrt(mean(cartesianError(finiteError).^2));
cartesianMax = max(cartesianError(finiteError));

[pickupError,pickupRequested] = indexedError( ...
    cartesianError,evaluationIndices,"pickup");
[placeError,placeRequested] = indexedError( ...
    cartesianError,evaluationIndices,"place");
requestedWaypointErrors = [ ...
    pickupError(pickupRequested),placeError(placeRequested)];
totalSaturationTime = sum(common.saturationTime);
taskSuccess = result.status == "completed" && common.success && ...
    cartesianRms <= 0.05 && cartesianMax <= 0.15 && ...
    all(requestedWaypointErrors <= 0.05) && ...
    totalSaturationTime == 0;

metrics = common;
metrics.desiredPosition = desiredPosition;
metrics.actualPosition = actualPosition;
metrics.cartesianError = cartesianError;
metrics.cartesianRms = cartesianRms;
metrics.cartesianMax = cartesianMax;
metrics.pickupError = pickupError;
metrics.placeError = placeError;
metrics.totalSaturationTime = totalSaturationTime;
metrics.taskSuccess = taskSuccess;
end

function [value,requested] = indexedError(errors,indices,name)
requested = isfield(indices,name);
if requested
    value = errors(indices.(name));
    if ~isfinite(value)
        value = Inf;
    end
else
    value = NaN;
end
end

function validateInputs(result,robot,reference,evaluationIndices)
requiredResult = ["time","q","qReference","tau","saturated","status"];
requiredReference = ["time","q","cartesian"];
if ~all(isfield(result,requiredResult)) || ...
        ~all(isfield(reference,requiredReference)) || ...
        ~isstruct(reference.cartesian) || ...
        ~isfield(reference.cartesian,"position") || ...
        ~isfield(robot,"L1") || ~isfield(robot,"L2")
    error("rrm:metrics:InvalidCartesianTaskInput", ...
        "Result, robot, reference, and task indices must be valid.");
end
sampleCount = numel(reference.time);
validShapes = isequal(size(reference.time),[sampleCount 1]) && ...
    isequal(size(result.time),[sampleCount 1]) && ...
    isequal(size(reference.q),[2 sampleCount]) && ...
    isequal(size(result.q),[2 sampleCount]) && ...
    isequal(size(result.qReference),[2 sampleCount]) && ...
    isequal(size(result.tau),[2 sampleCount]) && ...
    isequal(size(result.saturated),[2 sampleCount]) && ...
    isequal(size(reference.cartesian.position),[2 sampleCount]) && ...
    isequal(result.time,reference.time) && ...
    all(isfinite(reference.cartesian.position),"all");
if ~validShapes
    error("rrm:metrics:InvalidCartesianTaskInput", ...
        "Cartesian task arrays must share one finite sample grid.");
end
for name = ["pickup","place"]
    if isfield(evaluationIndices,name)
        value = evaluationIndices.(name);
        if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
                ~isfinite(value) || value ~= fix(value) || ...
                value < 1 || value > sampleCount
            error("rrm:metrics:InvalidCartesianTaskInput", ...
                "Waypoint evaluation indices must address valid samples.");
        end
    end
end
end
