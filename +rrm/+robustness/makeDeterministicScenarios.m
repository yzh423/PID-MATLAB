function scenarios = makeDeterministicScenarios(reference, baseOptions, mode)
%MAKEDETERMINISTICSCENARIOS Define prescribed Phase 4A stress cases.
arguments
    reference (1,1) struct
    baseOptions (1,1) struct
    mode (1,1) string {mustBeMember(mode,["full","smoke"])} = "full"
end

validateInputs(reference, baseOptions);
baseline = rrm.config.makeRobot("baseline");
zeroOptions = baseOptions;
zeroOptions.disturbanceTorque = zeros(2, numel(reference.time));
baseTorque = baseline.torqueLimits;

definitions = [ ...
    makeScenario("nominal", "nominal", baseline, zeroOptions, [NaN;NaN], 1, 1, 1); ...
    payloadScenario("payload-0.0kg", 0, baseline, zeroOptions); ...
    payloadScenario("payload-1.0kg", 1, baseline, zeroOptions); ...
    payloadScenario("payload-1.5kg", 1.5, baseline, zeroOptions); ...
    configurationScenario("configuration-compact", "compact", zeroOptions); ...
    configurationScenario("configuration-extended", "extended", zeroOptions); ...
    uncertaintyScenario("mass-inertia-minus-20pct", 0.8, baseline, zeroOptions); ...
    uncertaintyScenario("mass-inertia-minus-10pct", 0.9, baseline, zeroOptions); ...
    uncertaintyScenario("mass-inertia-plus-10pct", 1.1, baseline, zeroOptions); ...
    uncertaintyScenario("mass-inertia-plus-20pct", 1.2, baseline, zeroOptions); ...
    pulseScenario("disturbance-pulse", baseline, zeroOptions, reference); ...
    actuatorScenario("actuator-derated", baseline, zeroOptions, baseTorque); ...
    combinedScenario(zeroOptions, reference, baseTorque)];

validateScenarios(definitions, numel(reference.time));
if mode == "smoke"
    keep = ismember([definitions.name], ["nominal","disturbance-pulse", ...
        "actuator-derated","combined-deterministic"]);
    scenarios = definitions(keep);
else
    scenarios = definitions;
end
end

function scenario = payloadScenario(name, payload, baseline, options)
robot = baseline;
robot.payload = payload;
scenario = makeScenario(name, "payload", robot, options, ...
    [NaN;NaN], 1, 1, 1);
end

function scenario = configurationScenario(name, configuration, options)
robot = rrm.config.makeRobot(configuration);
baseline = rrm.config.makeRobot("baseline");
lengthScale = (robot.L1 + robot.L2) / (baseline.L1 + baseline.L2);
scenario = makeScenario(name, "configuration", robot, options, ...
    [NaN;NaN], lengthScale, 1, 1);
end

function scenario = uncertaintyScenario(name, scale, baseline, options)
robot = scaleMassAndInertia(baseline, scale);
scenario = makeScenario(name, "uncertainty", robot, options, ...
    [NaN;NaN], 1, scale, 1);
end

function scenario = pulseScenario(name, robot, options, reference)
options.disturbanceTorque = pulseHistory(reference.time);
scenario = makeScenario(name, "disturbance", robot, options, ...
    [2;2.1], 1, 1, 1);
end

function scenario = actuatorScenario(name, robot, options, baseTorque)
robot.torqueLimits = [18;10];
torqueScale = mean(robot.torqueLimits ./ baseTorque);
scenario = makeScenario(name, "actuator", robot, options, ...
    [NaN;NaN], 1, 1, torqueScale);
end

function scenario = combinedScenario(options, reference, baseTorque)
robot = rrm.config.makeRobot("extended");
robot.payload = 1.0;
robot = scaleMassAndInertia(robot, 1.2);
robot.torqueLimits = [18;10];
options.disturbanceTorque = pulseHistory(reference.time);
baseline = rrm.config.makeRobot("baseline");
lengthScale = (robot.L1 + robot.L2) / (baseline.L1 + baseline.L2);
torqueScale = mean(robot.torqueLimits ./ baseTorque);
scenario = makeScenario("combined-deterministic", "combined", ...
    robot, options, [2;2.1], lengthScale, 1.2, torqueScale);
end

function robot = scaleMassAndInertia(robot, scale)
robot.m1 = scale * robot.m1;
robot.m2 = scale * robot.m2;
robot.inertia = scale * robot.inertia;
end

function history = pulseHistory(time)
history = zeros(2, numel(time));
active = time >= 2.00 & time <= 2.10;
history(:,active) = repmat([4;-3], 1, nnz(active));
end

function scenario = makeScenario(name, category, robot, options, ...
        disturbanceWindow, lengthScale, uncertaintyScale, torqueScale)
scenario = struct( ...
    "name", name, ...
    "category", category, ...
    "robot", robot, ...
    "options", options, ...
    "disturbanceWindow", disturbanceWindow, ...
    "payload", robot.payload, ...
    "lengthScale", lengthScale, ...
    "uncertaintyScale", uncertaintyScale, ...
    "torqueScale", torqueScale, ...
    "recoveryBand", deg2rad(2), ...
    "recoveryDwell", 0.10);
end

function validateInputs(reference, options)
if ~isfield(reference, "time") || ~iscolumn(reference.time) || ...
        any(~isfinite(reference.time)) || isempty(reference.time)
    error("rrm:robustness:InvalidReference", ...
        "Reference must contain a finite time column.");
end
required = ["sampleTime","initialVelocity","disturbanceTorque", ...
    "successCriteria"];
if ~all(isfield(options, required))
    error("rrm:robustness:InvalidOptions", ...
        "Base options are missing required fields.");
end
end

function validateScenarios(scenarios, sampleCount)
names = [scenarios.name];
categories = ["nominal","payload","configuration","uncertainty", ...
    "disturbance","actuator","combined"];
if numel(unique(names)) ~= numel(names) || ...
        any(~ismember([scenarios.category], categories))
    error("rrm:robustness:InvalidScenario", ...
        "Scenario names must be unique and categories recognized.");
end
for index = 1:numel(scenarios)
    scenario = scenarios(index);
    robotValues = [scenario.robot.L1;scenario.robot.L2; ...
        scenario.robot.m1;scenario.robot.m2;scenario.robot.payload; ...
        scenario.robot.inertia;scenario.robot.torqueLimits];
    disturbance = scenario.options.disturbanceTorque;
    if any(~isfinite(robotValues)) || any(robotValues < 0) || ...
            ~isequal(size(disturbance), [2 sampleCount]) || ...
            ~isreal(disturbance) || any(~isfinite(disturbance), "all")
        error("rrm:robustness:InvalidScenario", ...
            "Scenario %s contains invalid physical data.", scenario.name);
    end
end
end
