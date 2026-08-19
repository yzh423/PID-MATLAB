%RUN_NOMINAL_PID Reproduce the Phase 1 nominal PID experiment.
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
controller = rrm.config.makePidController(robot);
options = rrm.config.makeSimulationOptions();
reference = rrm.trajectory.quintic( ...
    [0;0], deg2rad([45;60]), 3, options.sampleTime, 5);
result = rrm.simulation.runPid(robot, controller, reference, options);
metrics = rrm.metrics.evaluate(result, options.successCriteria);

save(fullfile(dataDirectory, "nominal_pid.mat"), ...
    "robot", "controller", "options", "reference", "result", "metrics");

trackingFigure = figure("Visible", "off", "Color", "white");
trackingLayout = tiledlayout(trackingFigure, 2, 1, ...
    "TileSpacing", "compact", "Padding", "compact");
for joint = 1:2
    axisHandle = nexttile(trackingLayout);
    plot(axisHandle, result.time, rad2deg(result.qReference(joint,:)), ...
        "--", "LineWidth", 1.4);
    hold(axisHandle, "on");
    plot(axisHandle, result.time, rad2deg(result.q(joint,:)), ...
        "LineWidth", 1.2);
    grid(axisHandle, "on");
    ylabel(axisHandle, sprintf("q_%d (deg)", joint));
    legend(axisHandle, "Reference", "Actual", "Location", "best");
end
xlabel(nexttile(trackingLayout, 2), "Time (s)");
title(trackingLayout, "Nominal PID Joint Tracking");
exportgraphics(trackingFigure, ...
    fullfile(figureDirectory, "nominal_pid_tracking.png"), ...
    "Resolution", 180);
close(trackingFigure);

torqueFigure = figure("Visible", "off", "Color", "white");
torqueLayout = tiledlayout(torqueFigure, 2, 1, ...
    "TileSpacing", "compact", "Padding", "compact");
for joint = 1:2
    axisHandle = nexttile(torqueLayout);
    plot(axisHandle, result.time, result.tau(joint,:), "LineWidth", 1.2);
    hold(axisHandle, "on");
    yline(axisHandle, robot.torqueLimits(joint), "--r");
    yline(axisHandle, -robot.torqueLimits(joint), "--r");
    grid(axisHandle, "on");
    ylabel(axisHandle, sprintf("tau_%d (N m)", joint));
end
xlabel(nexttile(torqueLayout, 2), "Time (s)");
title(torqueLayout, "Nominal PID Applied Torque");
exportgraphics(torqueFigure, ...
    fullfile(figureDirectory, "nominal_pid_torque.png"), ...
    "Resolution", 180);
close(torqueFigure);

fprintf("Nominal PID status: %s\n", result.status);
fprintf("Steady-state RMS error (rad): [%.6g, %.6g]\n", ...
    metrics.steadyStateRmsError(1), metrics.steadyStateRmsError(2));
fprintf("Steady-state max error (rad): [%.6g, %.6g]\n", ...
    metrics.steadyStateMaxAbsError(1), ...
    metrics.steadyStateMaxAbsError(2));
fprintf("Torque RMS (N m): [%.6g, %.6g]\n", ...
    metrics.controlRms(1), metrics.controlRms(2));
fprintf("Saturation time (s): [%.6g, %.6g]\n", ...
    metrics.saturationTime(1), metrics.saturationTime(2));
fprintf("Phase 1 success: %d\n", metrics.success);

assert(metrics.success, "rrm:experiment:AcceptanceFailure", ...
    "Nominal PID experiment did not meet Phase 1 acceptance criteria.");
