function summary = summarizeMatrix(runTable)
%SUMMARIZEMATRIX Aggregate deterministic robustness results by controller.
arguments
    runTable table
end

required = ["Controller","Success","JointRmsMean", ...
    "TotalSaturationTime"];
if ~all(ismember(required, string(runTable.Properties.VariableNames))) || ...
        isempty(runTable)
    error("rrm:robustness:InvalidRunTable", ...
        "Run table is empty or missing required variables.");
end

controllers = unique(runTable.Controller, "stable");
controllerCount = numel(controllers);
RunCount = zeros(controllerCount,1);
SuccessCount = zeros(controllerCount,1);
SuccessRate = zeros(controllerCount,1);
MeanJointRms = zeros(controllerCount,1);
WorstJointRms = zeros(controllerCount,1);
MeanEndEffectorRms = NaN(controllerCount,1);
WorstEndEffectorMax = NaN(controllerCount,1);
TotalSaturationTime = zeros(controllerCount,1);
FailedRunCount = zeros(controllerCount,1);

hasEndEffectorRms = ismember("EndEffectorRms", ...
    string(runTable.Properties.VariableNames));
hasEndEffectorMax = ismember("EndEffectorMax", ...
    string(runTable.Properties.VariableNames));
for index = 1:controllerCount
    selected = runTable.Controller == controllers(index);
    RunCount(index) = nnz(selected);
    SuccessCount(index) = nnz(runTable.Success(selected));
    SuccessRate(index) = SuccessCount(index) / RunCount(index);
    MeanJointRms(index) = mean(runTable.JointRmsMean(selected));
    WorstJointRms(index) = max(runTable.JointRmsMean(selected));
    TotalSaturationTime(index) = ...
        sum(runTable.TotalSaturationTime(selected));
    FailedRunCount(index) = RunCount(index) - SuccessCount(index);
    if hasEndEffectorRms
        MeanEndEffectorRms(index) = ...
            mean(runTable.EndEffectorRms(selected));
    end
    if hasEndEffectorMax
        WorstEndEffectorMax(index) = ...
            max(runTable.EndEffectorMax(selected));
    end
end

Controller = controllers;
summary = table(Controller, RunCount, SuccessCount, SuccessRate, ...
    MeanJointRms, WorstJointRms, MeanEndEffectorRms, ...
    WorstEndEffectorMax, TotalSaturationTime, FailedRunCount);
end
