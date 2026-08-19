function controller = applyPidMultipliers( ...
        baseController, multipliers, configuration)
%APPLYPIDMULTIPLIERS Map six bounded multipliers to physical PID gains.
arguments
    baseController (1,1) struct
    multipliers double
    configuration (1,1) struct
end

validateConfiguration(configuration);
if ~isequal(size(multipliers), [6 1]) || ...
        ~isreal(multipliers) || any(~isfinite(multipliers))
    error("rrm:optimization:InvalidMultipliers", ...
        "PID multipliers must be a finite real 6-by-1 vector.");
end
if any(multipliers < configuration.lowerBounds) || ...
        any(multipliers > configuration.upperBounds)
    error("rrm:optimization:MultiplierOutOfBounds", ...
        "PID multipliers must remain within the configured bounds.");
end

controller = baseController;
controller.name = "optimized-pid";
controller.Kp = baseController.Kp.*multipliers(1:2);
controller.Ki = baseController.Ki.*multipliers(3:4);
controller.Kd = baseController.Kd.*multipliers(5:6);
end

function validateConfiguration(configuration)
requiredFields = ["lowerBounds", "upperBounds"];
if ~all(isfield(configuration, requiredFields)) || ...
        ~isequal(size(configuration.lowerBounds), [6 1]) || ...
        ~isequal(size(configuration.upperBounds), [6 1]) || ...
        any(~isfinite(configuration.lowerBounds)) || ...
        any(~isfinite(configuration.upperBounds)) || ...
        any(configuration.lowerBounds > configuration.upperBounds)
    error("rrm:optimization:InvalidConfiguration", ...
        "Optimization bounds must be finite ordered 6-by-1 vectors.");
end
end
