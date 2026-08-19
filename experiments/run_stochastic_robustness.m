%RUN_STOCHASTIC_ROBUSTNESS Execute the Phase 4B seeded noise study.
projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);
if ~exist("outputRoot","var")
    outputRoot = fullfile(projectRoot,"results");
end
if ~exist("stochasticMode","var")
    stochasticMode = "full";
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
if ~exist("stochasticReference","var")
    reference = rrm.trajectory.quintic( ...
        [0;0],deg2rad([45;60]),3,simulationOptions.sampleTime,5);
else
    reference = stochasticReference;
end
controllerDefinitions(1) = struct("name","manual-pid", ...
    "controller",rrm.config.makePidController(baselineRobot));
controllerDefinitions(2) = struct("name","mamdani-fuzzy-pid", ...
    "controller",rrm.config.makeFuzzyPidController(baselineRobot));
controllerDefinitions(3) = struct("name","optimization-pid", ...
    "controller",rrm.config.makeOptimizedPidController(baselineRobot));
scenarios = rrm.robustness.makeStochasticScenarios( ...
    reference,simulationOptions,stochasticMode);

globalStateBefore = rng;
study = rrm.robustness.runStochasticStudy( ...
    controllerDefinitions,scenarios,reference, ...
    simulationOptions.successCriteria);
globalStateAfter = rng;
assert(isequal(globalStateBefore,globalStateAfter), ...
    "rrm:experiment:GlobalRandomStateChanged", ...
    "Stochastic orchestration changed MATLAB global RNG state.");
trialTable = study.table;
representativeRuns = study.representativeRuns;
summaryTable = rrm.robustness.summarizeStochasticStudy(trialTable);

nominalScenario = scenarios(1);
nominalScenario.robot = baselineRobot;
nominalScenario.options = simulationOptions;
nominalScenario.disturbanceWindow = [NaN;NaN];
nominalReferenceRuns = repmat(struct( ...
    "controllerName","","result",struct(),"metrics",struct(), ...
    "success",false),numel(controllerDefinitions),1);
for controllerIndex = 1:numel(controllerDefinitions)
    definition = controllerDefinitions(controllerIndex);
    result = rrm.simulation.runController(baselineRobot, ...
        definition.controller,reference,simulationOptions);
    metrics = rrm.robustness.evaluateStochasticRun( ...
        result,baselineRobot,simulationOptions.successCriteria, ...
        nominalScenario);
    nominalReferenceRuns(controllerIndex) = struct( ...
        "controllerName",definition.name, ...
        "result",result, ...
        "metrics",metrics, ...
        "success",metrics.robustness.success);
end

save(fullfile(dataDirectory,"stochastic_robustness.mat"), ...
    "stochasticMode","baselineRobot","simulationOptions","reference", ...
    "controllerDefinitions","scenarios","study","trialTable", ...
    "summaryTable","representativeRuns","nominalReferenceRuns", ...
    "-v7.3");
writetable(trialTable,fullfile(dataDirectory, ...
    "stochastic_robustness_trials.csv"));
writetable(summaryTable,fullfile(dataDirectory, ...
    "stochastic_robustness_summary.csv"));

writeFigure(successFigure(summaryTable),figureDirectory,"success");
writeFigure(accuracyFigure(summaryTable,nominalReferenceRuns), ...
    figureDirectory,"accuracy");
writeFigure(chatteringFigure(summaryTable,nominalReferenceRuns), ...
    figureDirectory,"chattering");
writeFigure(saturationFigure(summaryTable),figureDirectory,"saturation");
writeFigure(combinedFigure(summaryTable),figureDirectory,"combined");
writeFigure(representativeFigure(representativeRuns), ...
    figureDirectory,"representative");

disp(summaryTable(:,["Scenario","Controller","TrialCount", ...
    "SuccessCount","SuccessRate","SuccessLower95", ...
    "SuccessUpper95","MeanJointRms","MeanTorqueSlew", ...
    "WorstSaturationTime","NonRecoveryCount"]));

expectedTrials = 12;
expectedSummaryRows = 6;
expectedRepresentatives = 6;
if stochasticMode == "full"
    expectedTrials = 360;
    expectedSummaryRows = 12;
    expectedRepresentatives = 12;
end
trialKeys = trialTable.Scenario + "|" + trialTable.Controller + "|" + ...
    string(trialTable.Trial) + "|" + string(trialTable.Seed);
assert(height(trialTable) == expectedTrials && ...
    numel(unique(trialKeys)) == expectedTrials, ...
    "rrm:experiment:IncompleteStochasticStudy", ...
    "Stochastic trial matrix is incomplete or duplicated.");
assert(height(summaryTable) == expectedSummaryRows && ...
    numel(representativeRuns) == expectedRepresentatives, ...
    "rrm:experiment:IncompleteStochasticEvidence", ...
    "Stochastic summary or representative histories are incomplete.");
assert(all([nominalReferenceRuns.success]), ...
    "rrm:experiment:NominalReferenceFailure", ...
    "A frozen controller failed the noise-free nominal reference.");
finiteColumns = ["JointRmsMean","EndEffectorRms","EndEffectorMax", ...
    "TrackingErrorVarianceMean","TorqueSlewMean","ControlEnergy", ...
    "TotalSaturationTime","PositionNoiseRms","VelocityNoiseRms"];
assert(all(isfinite(trialTable{:,finiteColumns}),"all"), ...
    "rrm:experiment:InvalidStochasticMetric", ...
    "Every stochastic trial must retain finite reportable metrics.");
if stochasticMode == "full"
    assert(isequal(unique(trialTable.Seed).',(42001:42030)), ...
        "rrm:experiment:InvalidStochasticSeeds", ...
        "Full stochastic study used an unexpected seed schedule.");
end

function figureHandle = successFigure(summaryTable)
[scenarios,controllers,values] = summaryMatrix( ...
    summaryTable,"SuccessRate");
[~,~,lower] = summaryMatrix(summaryTable,"SuccessLower95");
[~,~,upper] = summaryMatrix(summaryTable,"SuccessUpper95");
figureHandle = figure("Visible","off","Color","white", ...
    "Position",[100 100 900 480]);
axisHandle = axes(figureHandle);
bars = bar(axisHandle,values,"grouped");
hold(axisHandle,"on");
for index = 1:numel(bars)
    errorbar(axisHandle,bars(index).XEndPoints,values(:,index), ...
        values(:,index)-lower(:,index),upper(:,index)-values(:,index), ...
        "k","LineStyle","none","LineWidth",1);
end
ylim(axisHandle,[0 1.05]);
xticks(axisHandle,1:numel(scenarios));
xticklabels(axisHandle,scenarios);
xtickangle(axisHandle,20);
ylabel(axisHandle,"Task success rate");
legend(axisHandle,controllers,"Location","best");
grid(axisHandle,"on");
title(axisHandle,"Seeded Trial Success with Wilson 95% Intervals");
end

function figureHandle = accuracyFigure(summaryTable,nominalRuns)
figureHandle = sweepWithNominal(summaryTable,nominalRuns, ...
    "MeanJointRms","Mean joint RMS error (rad)", ...
    @(run) mean(run.metrics.robustness.common.rmsError), ...
    "Tracking Accuracy versus Measurement Noise");
end

function figureHandle = chatteringFigure(summaryTable,nominalRuns)
figureHandle = sweepWithNominal(summaryTable,nominalRuns, ...
    "MeanTorqueSlew","Mean torque slew RMS (N m/s)", ...
    @(run) run.metrics.torqueSlewMean, ...
    "Control Chattering versus Measurement Noise");
end

function figureHandle = sweepWithNominal( ...
        summaryTable,nominalRuns,metricName,yLabel,nominalMetric,titleText)
noiseRows = startsWith(summaryTable.Scenario,"noise-");
controllers = unique(summaryTable.Controller,"stable");
figureHandle = figure("Visible","off","Color","white");
axisHandle = axes(figureHandle);
hold(axisHandle,"on");
for index = 1:numel(controllers)
    rows = noiseRows & summaryTable.Controller == controllers(index);
    x = summaryTable.PositionNoiseStdDeg(rows);
    y = summaryTable.(metricName)(rows);
    [x,order] = sort(x);
    nominal = nominalRuns( ...
        [nominalRuns.controllerName] == controllers(index));
    plot(axisHandle,[0;x],[nominalMetric(nominal);y(order)], ...
        "-o","LineWidth",1.3,"DisplayName",controllers(index));
end
xlabel(axisHandle,"Joint-position noise standard deviation (deg)");
ylabel(axisHandle,yLabel);
legend(axisHandle,"Location","best");
grid(axisHandle,"on");
title(axisHandle,titleText);
end

function figureHandle = saturationFigure(summaryTable)
[scenarios,controllers,meanValues] = summaryMatrix( ...
    summaryTable,"MeanSaturationTime");
[~,~,worstValues] = summaryMatrix(summaryTable,"WorstSaturationTime");
figureHandle = figure("Visible","off","Color","white", ...
    "Position",[100 100 900 620]);
layout = tiledlayout(figureHandle,2,1, ...
    "TileSpacing","compact","Padding","compact");
axisHandle = nexttile(layout);
bar(axisHandle,meanValues,"grouped");
configureScenarioBars(axisHandle,scenarios,controllers, ...
    "Mean joint-summed saturation (s)");
axisHandle = nexttile(layout);
bar(axisHandle,worstValues,"grouped");
configureScenarioBars(axisHandle,scenarios,controllers, ...
    "Worst joint-summed saturation (s)");
title(layout,"Actuator Saturation across Seeded Trials");
end

function figureHandle = combinedFigure(summaryTable)
combined = summaryTable(summaryTable.Scenario == ...
    "combined-stochastic",:);
figureHandle = figure("Visible","off","Color","white");
layout = tiledlayout(figureHandle,1,2, ...
    "TileSpacing","compact","Padding","compact");
axisHandle = nexttile(layout);
bars = bar(axisHandle,combined.SuccessRate);
hold(axisHandle,"on");
errorbar(axisHandle,bars.XEndPoints,combined.SuccessRate, ...
    combined.SuccessRate-combined.SuccessLower95, ...
    combined.SuccessUpper95-combined.SuccessRate,"k", ...
    "LineStyle","none");
ylim(axisHandle,[0 1.05]);
configureControllerAxis(axisHandle,combined.Controller, ...
    "Success rate");
axisHandle = nexttile(layout);
bar(axisHandle,combined.P95EndEffectorMax);
configureControllerAxis(axisHandle,combined.Controller, ...
    "95th-percentile EE max error (m)");
title(layout,"Final Payload + Noise + Disturbance + Saturation Stress");
end

function figureHandle = representativeFigure(representativeRuns)
selected = representativeRuns( ...
    [representativeRuns.scenarioName] == "noise-medium");
figureHandle = figure("Visible","off","Color","white", ...
    "Position",[100 100 980 620]);
layout = tiledlayout(figureHandle,2,1, ...
    "TileSpacing","compact","Padding","compact");
axisHandle = nexttile(layout);
hold(axisHandle,"on");
for index = 1:numel(selected)
    result = selected(index).result;
    plot(axisHandle,result.time,rad2deg( ...
        result.qReference(1,:)-result.q(1,:)),"LineWidth",1.15, ...
        "DisplayName",selected(index).controllerName + " true");
    plot(axisHandle,result.time,rad2deg( ...
        result.qReference(1,:)-result.qMeasured(1,:)),":", ...
        "LineWidth",0.9,"DisplayName", ...
        selected(index).controllerName + " measured");
end
ylabel(axisHandle,"Joint 1 error (deg)");
grid(axisHandle,"on");
legend(axisHandle,"Location","best");
axisHandle = nexttile(layout);
hold(axisHandle,"on");
for index = 1:numel(selected)
    result = selected(index).result;
    plot(axisHandle,result.time,result.tau(1,:),"LineWidth",1.05, ...
        "DisplayName",selected(index).controllerName);
end
xlabel(axisHandle,"Time (s)");
ylabel(axisHandle,"Joint 1 torque (N m)");
grid(axisHandle,"on");
legend(axisHandle,"Location","best");
title(layout,"Representative Medium-Noise Trial (seed 42001)");
end

function [scenarios,controllers,values] = summaryMatrix(summaryTable,name)
scenarios = unique(summaryTable.Scenario,"stable");
controllers = unique(summaryTable.Controller,"stable");
values = NaN(numel(scenarios),numel(controllers));
for scenarioIndex = 1:numel(scenarios)
    for controllerIndex = 1:numel(controllers)
        selected = summaryTable.Scenario == scenarios(scenarioIndex) & ...
            summaryTable.Controller == controllers(controllerIndex);
        values(scenarioIndex,controllerIndex) = ...
            summaryTable.(name)(selected);
    end
end
end

function configureScenarioBars(axisHandle,scenarios,controllers,yLabel)
xticks(axisHandle,1:numel(scenarios));
xticklabels(axisHandle,scenarios);
xtickangle(axisHandle,20);
ylabel(axisHandle,yLabel);
legend(axisHandle,controllers,"Location","best");
grid(axisHandle,"on");
end

function configureControllerAxis(axisHandle,controllers,yLabel)
xticks(axisHandle,1:numel(controllers));
xticklabels(axisHandle,controllers);
xtickangle(axisHandle,20);
ylabel(axisHandle,yLabel);
grid(axisHandle,"on");
end

function writeFigure(figureHandle,figureDirectory,suffix)
exportgraphics(figureHandle,fullfile(figureDirectory, ...
    "stochastic_robustness_" + suffix + ".png"),"Resolution",180);
close(figureHandle);
end
