function correction = mamdani(configuration, errorValue, rateValue)
%MAMDANI Evaluate normalized Kp, Ki, and Kd correction rule bases.
arguments
    configuration (1,1) struct
    errorValue (1,1) double {mustBeFinite, mustBeReal}
    rateValue (1,1) double {mustBeFinite, mustBeReal}
end

validateConfiguration(configuration);
errorMembership = rrm.fuzzy.membershipFive(errorValue);
rateMembership = rrm.fuzzy.membershipFive(rateValue);
firingStrength = min(errorMembership, rateMembership.');

gainNames = ["Kp", "Ki", "Kd"];
correction = zeros(3,1);
for gain = 1:numel(gainNames)
    ruleTable = configuration.rules.(gainNames(gain));
    aggregate = zeros(size(configuration.outputUniverse));
    for errorLabel = 1:5
        for rateLabel = 1:5
            outputLabel = ruleTable(errorLabel, rateLabel);
            implication = min( ...
                firingStrength(errorLabel, rateLabel), ...
                configuration.outputMembership(outputLabel,:));
            aggregate = max(aggregate, implication);
        end
    end

    area = sum(aggregate);
    if area > 0
        correction(gain) = ...
            sum(configuration.outputUniverse.*aggregate) / area;
    end
end
correction = max(-1, min(1, correction));
end

function validateConfiguration(configuration)
requiredFields = ["rules", "outputUniverse", "outputMembership"];
if ~all(isfield(configuration, requiredFields))
    invalidConfiguration();
end

universe = configuration.outputUniverse;
if ~isvector(universe) || isempty(universe) || ...
        any(~isfinite(universe)) || any(diff(universe) <= 0)
    invalidConfiguration();
end
if ~isequal(size(configuration.outputMembership), [5 numel(universe)]) || ...
        any(~isfinite(configuration.outputMembership), "all") || ...
        any(configuration.outputMembership < 0, "all")
    invalidConfiguration();
end

gainNames = ["Kp", "Ki", "Kd"];
if ~isstruct(configuration.rules) || ...
        ~all(isfield(configuration.rules, gainNames))
    invalidConfiguration();
end
for gainName = gainNames
    ruleTable = configuration.rules.(gainName);
    if ~isequal(size(ruleTable), [5 5]) || ...
            any(~isfinite(ruleTable), "all") || ...
            any(ruleTable < 1 | ruleTable > 5 | ruleTable ~= fix(ruleTable), "all")
        invalidConfiguration();
    end
end
end

function invalidConfiguration()
error("rrm:fuzzy:InvalidConfiguration", ...
    "Fuzzy rule tables or output membership definitions are invalid.");
end
