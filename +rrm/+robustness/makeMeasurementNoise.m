function noise = makeMeasurementNoise(spec, sampleCount, seed)
%MAKEMEASUREMENTNOISE Generate reproducible local sensor-noise histories.

validateSpecification(spec, sampleCount);
validateSeed(seed);
stream = RandStream("mt19937ar", "Seed", seed);
position = spec.positionStd .* randn(stream, 2, sampleCount);
velocity = spec.velocityStd .* randn(stream, 2, sampleCount);
noise = struct( ...
    "position", position, ...
    "velocity", velocity, ...
    "seed", seed);
end

function validateSpecification(spec, sampleCount)
required = ["positionStd","velocityStd"];
validCount = isnumeric(sampleCount) && isreal(sampleCount) && ...
    isscalar(sampleCount) && isfinite(sampleCount) && ...
    sampleCount >= 1 && sampleCount == floor(sampleCount);
if ~isstruct(spec) || ~isscalar(spec) || ...
        ~all(isfield(spec, required)) || ~validCount
    error("rrm:robustness:InvalidNoiseSpecification", ...
        "Noise specification and sample count are invalid.");
end
for fieldName = required
    value = spec.(fieldName);
    if ~isnumeric(value) || ~isreal(value) || ...
            ~isequal(size(value), [2 1]) || ...
            any(~isfinite(value)) || any(value < 0)
        error("rrm:robustness:InvalidNoiseSpecification", ...
            "Noise deviations must be finite nonnegative 2-by-1 vectors.");
    end
end
end

function validateSeed(seed)
isValid = isnumeric(seed) && isreal(seed) && isscalar(seed) && ...
    isfinite(seed) && seed >= 0 && seed == floor(seed) && ...
    seed <= double(intmax("uint32"));
if ~isValid
    error("rrm:robustness:InvalidSeed", ...
        "Seed must be a nonnegative uint32-range integer.");
end
end
