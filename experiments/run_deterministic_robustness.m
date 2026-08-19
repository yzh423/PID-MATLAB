%RUN_DETERMINISTIC_ROBUSTNESS Execute the Phase 4A robustness matrix.
projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);
if ~exist("outputRoot","var")
    outputRoot = fullfile(projectRoot,"results");
end
if ~exist("robustnessMode","var")
    robustnessMode = "full";
end

dataDirectory = fullfile(outputRoot,"data");
figureDirectory = fullfile(outputRoot,"figures");
if ~isfolder(dataDirectory)
    mkdir(dataDirectory);
end
if ~isfolder(figureDirectory)
    mkdir(figureDirectory);
end

baselineRobot = rrm.config.makeRobot("baseline");
simulationOptions = rrm.config.makeSimulationOptions();
if ~exist("robustnessReference","var")
    reference = rrm.trajectory.quintic( ...
        [0;0],deg2rad([45;60]),3,simulationOptions.sampleTime,5);
else
    reference = robustnessReference;
end
controllerDefinitions(1) = struct("name","manual-pid", ...
    "controller",rrm.config.makePidController(baselineRobot));
controllerDefinitions(2) = struct("name","mamdani-fuzzy-pid", ...
    "controller",rrm.config.makeFuzzyPidController(baselineRobot));
controllerDefinitions(3) = struct("name","optimization-pid", ...
    "controller",rrm.config.makeOptimizedPidController(baselineRobot));
scenarios = rrm.robustness.makeDeterministicScenarios( ...
    reference,simulationOptions,robustnessMode);
matrix = rrm.robustness.runDeterministicMatrix( ...
    controllerDefinitions,scenarios,reference, ...
    simulationOptions.successCriteria);
runTable = matrix.table;
summaryTable = rrm.robustness.summarizeMatrix(runTable);

save(fullfile(dataDirectory,"deterministic_robustness.mat"), ...
    "robustnessMode","baselineRobot","simulationOptions","reference", ...
    "controllerDefinitions","scenarios","matrix","runTable", ...
    "summaryTable");
writetable(runTable,fullfile(dataDirectory, ...
    "deterministic_robustness_runs.csv"));
writetable(summaryTable,fullfile(dataDirectory, ...
    "deterministic_robustness_summary.csv"));

payloadRows = runTable.Category == "payload" | ...
    runTable.Category == "nominal";
payloadFigure = sweepFigure(runTable(payloadRows,:),"Payload", ...
    "Payload (kg)","Payload Robustness");
writeFigure(payloadFigure,figureDirectory,"payload");

configurationRows = runTable.Category == "configuration" | ...
    runTable.Category == "nominal";
configurationFigure = sweepFigure(runTable(configurationRows,:), ...
    "LengthScale","Total link-length scale", ...
    "Prescribed Link Configurations");
writeFigure(configurationFigure,figureDirectory,"configuration");

uncertaintyRows = runTable.Category == "uncertainty" | ...
    runTable.Category == "nominal";
uncertaintyFigure = sweepFigure(runTable(uncertaintyRows,:), ...
    "UncertaintyScale","Mass and inertia scale", ...
    "Plant-Parameter Uncertainty");
writeFigure(uncertaintyFigure,figureDirectory,"uncertainty");

disturbanceFigure = disturbancePlot(matrix.runs);
writeFigure(disturbanceFigure,figureDirectory,"disturbance");
heatmapFigure = heatmapPlot(runTable);
writeFigure(heatmapFigure,figureDirectory,"heatmap");
summaryFigure = summaryPlot(summaryTable);
writeFigure(summaryFigure,figureDirectory,"summary");

disp(summaryTable);
failedRows = runTable(~runTable.Success, ...
    ["Scenario","Controller","Status","JointRmsMean", ...
    "EndEffectorMax","TotalSaturationTime","RecoveryTime"]);
fprintf("Deterministic robustness mode: %s; runs: %d; failures: %d\n", ...
    robustnessMode,height(runTable),height(failedRows));
if ~isempty(failedRows)
    disp(failedRows);
end

expectedScenarios = 4;
if robustnessMode == "full"
    expectedScenarios = 13;
end
assert(height(runTable) == 3*expectedScenarios && ...
    numel(unique(runTable.Scenario + "|" + runTable.Controller)) == ...
    height(runTable),"rrm:experiment:IncompleteRobustnessMatrix", ...
    "Robustness matrix is missing or duplicating controller-scenario pairs.");
nominalRows = runTable.Scenario == "nominal";
assert(nnz(nominalRows) == 3 && all(runTable.Success(nominalRows)), ...
    "rrm:experiment:NominalRobustnessFailure", ...
    "Every frozen controller must pass the nominal robustness row.");
finiteColumns = ["JointRms1","JointRms2","JointRmsMean", ...
    "EndEffectorRms","EndEffectorMax","ControlEnergy", ...
    "TotalSaturationTime"];
assert(all(isfinite(runTable{:,finiteColumns}),"all"), ...
    "rrm:experiment:InvalidRobustnessMetric", ...
    "Every robustness run must retain finite reportable metrics.");

function figureHandle = sweepFigure(runTable,xVariable,xLabel,titleText)
figureHandle = figure("Visible","off","Color","white");
layout = tiledlayout(figureHandle,2,1, ...
    "TileSpacing","compact","Padding","compact");
controllers = unique(runTable.Controller,"stable");
metrics = ["JointRmsMean","ControlEnergy"];
yLabels = ["Mean joint RMS (rad)","Control energy (N^2 m^2 s)"];
for metricIndex = 1:2
    axisHandle = nexttile(layout);
    hold(axisHandle,"on");
    for controllerIndex = 1:numel(controllers)
        rows = runTable.Controller == controllers(controllerIndex);
        x = runTable.(xVariable)(rows);
        y = runTable.(metrics(metricIndex))(rows);
        [x,order] = sort(x);
        plot(axisHandle,x,y(order),"-o","LineWidth",1.25, ...
            "DisplayName",controllers(controllerIndex));
    end
    grid(axisHandle,"on");
    ylabel(axisHandle,yLabels(metricIndex));
    legend(axisHandle,"Location","best");
end
xlabel(nexttile(layout,2),xLabel);
title(layout,titleText);
end

function figureHandle = disturbancePlot(runs)
figureHandle = figure("Visible","off","Color","white");
axisHandle = axes(figureHandle);
hold(axisHandle,"on");
for index = 1:numel(runs)
    if runs(index).scenarioName ~= "disturbance-pulse"
        continue
    end
    result = runs(index).result;
    errorNorm = vecnorm(rad2deg(result.qReference-result.q),2,1);
    plot(axisHandle,result.time,errorNorm,"LineWidth",1.25, ...
        "DisplayName",runs(index).controllerName);
    recovery = runs(index).metrics.recoveryTime;
    if isfinite(recovery)
        xline(axisHandle,2.10+recovery,":", ...
            runs(index).controllerName + " recovered", ...
            "HandleVisibility","off");
    end
end
xline(axisHandle,2.00,"--k","Pulse start","HandleVisibility","off");
xline(axisHandle,2.10,"--k","Pulse end","HandleVisibility","off");
grid(axisHandle,"on");
xlim(axisHandle,[1.75 min(2.75,max(runs(1).result.time))]);
xlabel(axisHandle,"Time (s)");
ylabel(axisHandle,"Joint-error norm (deg)");
legend(axisHandle,"Location","best");
title(axisHandle,"Deterministic Disturbance and Recovery");
end

function figureHandle = heatmapPlot(runTable)
scenarios = unique(runTable.Scenario,"stable");
controllers = unique(runTable.Controller,"stable");
values = NaN(numel(scenarios),numel(controllers));
for scenarioIndex = 1:numel(scenarios)
    for controllerIndex = 1:numel(controllers)
        row = runTable.Scenario == scenarios(scenarioIndex) & ...
            runTable.Controller == controllers(controllerIndex);
        values(scenarioIndex,controllerIndex) = runTable.JointRmsMean(row);
    end
end
normalized = values ./ max(min(values,[],2),eps);
figureHandle = figure("Visible","off","Color","white", ...
    "Position",[100 100 760 520]);
axisHandle = axes(figureHandle);
imagesc(axisHandle,normalized);
colorbar(axisHandle);
xticks(axisHandle,1:numel(controllers));
xticklabels(axisHandle,controllers);
yticks(axisHandle,1:numel(scenarios));
yticklabels(axisHandle,scenarios);
xlabel(axisHandle,"Frozen controller");
ylabel(axisHandle,"Scenario");
title(axisHandle,"Joint RMS Ratio to Best Controller in Each Scenario");
end

function figureHandle = summaryPlot(summaryTable)
figureHandle = figure("Visible","off","Color","white");
layout = tiledlayout(figureHandle,1,3, ...
    "TileSpacing","compact","Padding","compact");
variables = ["SuccessCount","WorstEndEffectorMax", ...
    "TotalSaturationTime"];
yLabels = ["Successful runs","Worst EE error (m)", ...
    "Total saturation (s)"];
for index = 1:3
    axisHandle = nexttile(layout);
    bar(axisHandle,summaryTable.(variables(index)));
    xticks(axisHandle,1:height(summaryTable));
    xticklabels(axisHandle,summaryTable.Controller);
    xtickangle(axisHandle,25);
    ylabel(axisHandle,yLabels(index));
    grid(axisHandle,"on");
end
title(layout,"Deterministic Robustness Summary");
end

function writeFigure(figureHandle,figureDirectory,suffix)
exportgraphics(figureHandle,fullfile(figureDirectory, ...
    "deterministic_robustness_" + suffix + ".png"),"Resolution",180);
close(figureHandle);
end
