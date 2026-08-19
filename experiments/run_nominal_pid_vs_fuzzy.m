%RUN_NOMINAL_PID_VS_FUZZY Reproduce the Phase 2 fair comparison.
projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);
if ~exist("outputRoot", "var")
    outputRoot = fullfile(projectRoot, "results");
end

dataDirectory = fullfile(outputRoot, "data");
figureDirectory = fullfile(outputRoot, "figures");
if ~isfolder(dataDirectory)
    mkdir(dataDirectory);
end
if ~isfolder(figureDirectory)
    mkdir(figureDirectory);
end

robot = rrm.config.makeRobot("baseline");
pidController = rrm.config.makePidController(robot);
fuzzyController = rrm.config.makeFuzzyPidController(robot);
options = rrm.config.makeSimulationOptions();
reference = rrm.trajectory.quintic( ...
    [0;0], deg2rad([45;60]), 3, options.sampleTime, 5);

pidResult = rrm.simulation.runPid( ...
    robot, pidController, reference, options);
fuzzyResult = rrm.simulation.runFuzzyPid( ...
    robot, fuzzyController, reference, options);
pidMetrics = rrm.metrics.evaluate(pidResult, options.successCriteria);
fuzzyMetrics = rrm.metrics.evaluate(fuzzyResult, options.successCriteria);

save(fullfile(dataDirectory, "nominal_pid_vs_fuzzy.mat"), ...
    "robot", "pidController", "fuzzyController", "options", ...
    "reference", "pidResult", "fuzzyResult", ...
    "pidMetrics", "fuzzyMetrics");

trackingFigure = figure("Visible", "off", "Color", "white");
trackingLayout = tiledlayout(trackingFigure, 2, 1, ...
    "TileSpacing", "compact", "Padding", "compact");
for joint = 1:2
    axisHandle = nexttile(trackingLayout);
    plot(axisHandle, reference.time, rad2deg(reference.q(joint,:)), ...
        "--k", "LineWidth", 1.4);
    hold(axisHandle, "on");
    plot(axisHandle, pidResult.time, rad2deg(pidResult.q(joint,:)), ...
        "LineWidth", 1.15);
    plot(axisHandle, fuzzyResult.time, rad2deg(fuzzyResult.q(joint,:)), ...
        "LineWidth", 1.15);
    grid(axisHandle, "on");
    ylabel(axisHandle, sprintf("q_%d (deg)", joint));
    legend(axisHandle, "Reference", "PID", "Fuzzy-PID", ...
        "Location", "best");
end
xlabel(nexttile(trackingLayout, 2), "Time (s)");
title(trackingLayout, "Nominal Joint Tracking Under Identical Conditions");
writeFigure(trackingFigure, figureDirectory, "tracking");

errorFigure = figure("Visible", "off", "Color", "white");
errorLayout = tiledlayout(errorFigure, 2, 1, ...
    "TileSpacing", "compact", "Padding", "compact");
for joint = 1:2
    axisHandle = nexttile(errorLayout);
    plot(axisHandle, pidResult.time, ...
        rad2deg(pidResult.qReference(joint,:)-pidResult.q(joint,:)), ...
        "LineWidth", 1.15);
    hold(axisHandle, "on");
    plot(axisHandle, fuzzyResult.time, ...
        rad2deg(fuzzyResult.qReference(joint,:)-fuzzyResult.q(joint,:)), ...
        "LineWidth", 1.15);
    yline(axisHandle, 0, ":k");
    grid(axisHandle, "on");
    ylabel(axisHandle, sprintf("e_%d (deg)", joint));
    legend(axisHandle, "PID", "Fuzzy-PID", "Location", "best");
end
xlabel(nexttile(errorLayout, 2), "Time (s)");
title(errorLayout, "Joint Tracking Error");
writeFigure(errorFigure, figureDirectory, "error");

torqueFigure = figure("Visible", "off", "Color", "white");
torqueLayout = tiledlayout(torqueFigure, 2, 1, ...
    "TileSpacing", "compact", "Padding", "compact");
for joint = 1:2
    axisHandle = nexttile(torqueLayout);
    plot(axisHandle, pidResult.time, pidResult.tau(joint,:), ...
        "LineWidth", 1.15);
    hold(axisHandle, "on");
    plot(axisHandle, fuzzyResult.time, fuzzyResult.tau(joint,:), ...
        "LineWidth", 1.15);
    yline(axisHandle, robot.torqueLimits(joint), "--r", "Limit");
    yline(axisHandle, -robot.torqueLimits(joint), "--r");
    ylim(axisHandle, 1.05*[-robot.torqueLimits(joint), ...
        robot.torqueLimits(joint)]);
    grid(axisHandle, "on");
    ylabel(axisHandle, sprintf("tau_%d (N m)", joint));
    legend(axisHandle, "PID", "Fuzzy-PID", "Location", "best");
end
xlabel(nexttile(torqueLayout, 2), "Time (s)");
title(torqueLayout, "Applied Torque and Common Actuator Limits");
writeFigure(torqueFigure, figureDirectory, "torque");

gainFigure = figure("Visible", "off", "Color", "white");
gainLayout = tiledlayout(gainFigure, 3, 1, ...
    "TileSpacing", "compact", "Padding", "compact");
gainNames = ["Kp", "Ki", "Kd"];
for gain = 1:numel(gainNames)
    axisHandle = nexttile(gainLayout);
    history = fuzzyResult.("effective" + gainNames(gain));
    plot(axisHandle, fuzzyResult.time, history(1,:), "LineWidth", 1.15);
    hold(axisHandle, "on");
    plot(axisHandle, fuzzyResult.time, history(2,:), "LineWidth", 1.15);
    grid(axisHandle, "on");
    ylabel(axisHandle, gainNames(gain));
    legend(axisHandle, "Joint 1", "Joint 2", "Location", "best");
end
xlabel(nexttile(gainLayout, 3), "Time (s)");
title(gainLayout, "Fuzzy-PID Effective Gain History");
writeFigure(gainFigure, figureDirectory, "gains");

controllerName = repelem(["PID";"Fuzzy-PID"], 2);
joint = repmat((1:2).', 2, 1);
steadyRms = [pidMetrics.steadyStateRmsError; ...
    fuzzyMetrics.steadyStateRmsError];
steadyMax = [pidMetrics.steadyStateMaxAbsError; ...
    fuzzyMetrics.steadyStateMaxAbsError];
torqueRms = [pidMetrics.controlRms; fuzzyMetrics.controlRms];
saturationTime = [pidMetrics.saturationTime; fuzzyMetrics.saturationTime];
metricTable = table(controllerName, joint, steadyRms, steadyMax, ...
    torqueRms, saturationTime, VariableNames=["Controller", "Joint", ...
    "SteadyRmsRad", "SteadyMaxRad", "TorqueRmsNm", "SaturationTimeS"]);
disp(metricTable);
fprintf("PID status/success: %s / %d\n", ...
    pidResult.status, pidMetrics.success);
fprintf("Fuzzy-PID status/success: %s / %d\n", ...
    fuzzyResult.status, fuzzyMetrics.success);

assert(pidMetrics.success && fuzzyMetrics.success, ...
    "rrm:experiment:AcceptanceFailure", ...
    "A nominal controller did not meet the common acceptance criteria.");
assert(all(fuzzyMetrics.saturationTime == 0), ...
    "rrm:experiment:FuzzySaturation", ...
    "Fuzzy-PID used torque saturation during the nominal comparison.");

function writeFigure(figureHandle, figureDirectory, suffix)
exportgraphics(figureHandle, fullfile(figureDirectory, ...
    "nominal_pid_vs_fuzzy_" + suffix + ".png"), "Resolution", 180);
close(figureHandle);
end
