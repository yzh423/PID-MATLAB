function matrix = runDeterministicMatrix( ...
        controllerDefinitions, scenarios, reference, criteria)
%RUNDETERMINISTICMATRIX Execute every frozen-controller/scenario pair.
arguments
    controllerDefinitions struct
    scenarios struct
    reference (1,1) struct
    criteria (1,1) struct
end

validateDefinitions(controllerDefinitions, scenarios);
runCount = numel(controllerDefinitions) * numel(scenarios);
runs = repmat(struct("scenarioName", "", "controllerName", "", ...
    "scenario", struct(), "controller", struct(), ...
    "result", struct(), "metrics", struct()), runCount, 1);

Scenario = strings(runCount,1);
Category = strings(runCount,1);
Controller = strings(runCount,1);
Status = strings(runCount,1);
Success = false(runCount,1);
JointRms1 = NaN(runCount,1);
JointRms2 = NaN(runCount,1);
JointRmsMean = NaN(runCount,1);
JointMax1 = NaN(runCount,1);
JointMax2 = NaN(runCount,1);
SteadyRms1 = NaN(runCount,1);
SteadyRms2 = NaN(runCount,1);
EndEffectorRms = NaN(runCount,1);
EndEffectorMax = NaN(runCount,1);
TorqueRms1 = NaN(runCount,1);
TorqueRms2 = NaN(runCount,1);
ControlEnergy = NaN(runCount,1);
TotalSaturationTime = NaN(runCount,1);
RecoveryTime = NaN(runCount,1);
Payload = NaN(runCount,1);
LengthScale = NaN(runCount,1);
UncertaintyScale = NaN(runCount,1);
TorqueScale = NaN(runCount,1);

row = 0;
for scenarioIndex = 1:numel(scenarios)
    scenario = scenarios(scenarioIndex);
    for controllerIndex = 1:numel(controllerDefinitions)
        definition = controllerDefinitions(controllerIndex);
        row = row + 1;
        result = rrm.simulation.runController(scenario.robot, ...
            definition.controller, reference, scenario.options);
        metrics = rrm.robustness.evaluateRun( ...
            result, scenario.robot, criteria, scenario);

        runs(row) = struct( ...
            "scenarioName", scenario.name, ...
            "controllerName", definition.name, ...
            "scenario", scenario, ...
            "controller", definition.controller, ...
            "result", result, ...
            "metrics", metrics);
        common = metrics.common;
        Scenario(row) = scenario.name;
        Category(row) = scenario.category;
        Controller(row) = definition.name;
        Status(row) = result.status;
        Success(row) = metrics.success;
        JointRms1(row) = common.rmsError(1);
        JointRms2(row) = common.rmsError(2);
        JointRmsMean(row) = mean(common.rmsError);
        JointMax1(row) = common.maxAbsError(1);
        JointMax2(row) = common.maxAbsError(2);
        SteadyRms1(row) = common.steadyStateRmsError(1);
        SteadyRms2(row) = common.steadyStateRmsError(2);
        EndEffectorRms(row) = metrics.endEffectorRmsError;
        EndEffectorMax(row) = metrics.endEffectorMaxError;
        TorqueRms1(row) = common.controlRms(1);
        TorqueRms2(row) = common.controlRms(2);
        ControlEnergy(row) = common.controlEnergy;
        TotalSaturationTime(row) = metrics.totalSaturationTime;
        RecoveryTime(row) = metrics.recoveryTime;
        Payload(row) = scenario.payload;
        LengthScale(row) = scenario.lengthScale;
        UncertaintyScale(row) = scenario.uncertaintyScale;
        TorqueScale(row) = scenario.torqueScale;
    end
end

runTable = table(Scenario, Category, Controller, Status, Success, ...
    JointRms1, JointRms2, JointRmsMean, JointMax1, JointMax2, ...
    SteadyRms1, SteadyRms2, EndEffectorRms, EndEffectorMax, ...
    TorqueRms1, TorqueRms2, ControlEnergy, TotalSaturationTime, ...
    RecoveryTime, Payload, LengthScale, UncertaintyScale, TorqueScale);
matrix = struct("runs", runs, "table", runTable);
end

function validateDefinitions(definitions, scenarios)
if isempty(definitions) || ~all(isfield(definitions, ["name","controller"]))
    error("rrm:robustness:InvalidControllerDefinitions", ...
        "Controller definitions require name and controller fields.");
end
names = string({definitions.name});
hasType = arrayfun(@(item) isfield(item.controller, "type"), definitions);
if numel(unique(names)) ~= numel(names) || any(strlength(names) == 0) || ...
        ~all(hasType)
    error("rrm:robustness:InvalidControllerDefinitions", ...
        "Controller labels must be unique and controllers must define type.");
end
if isempty(scenarios) || ~all(isfield(scenarios, ...
        ["name","robot","options","disturbanceWindow"])) || ...
        numel(unique([scenarios.name])) ~= numel(scenarios)
    error("rrm:robustness:InvalidScenario", ...
        "Scenarios must be nonempty, complete, and uniquely named.");
end
end
