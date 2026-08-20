function writeVideo(robot,multibodyRun,videoPath,videoOptions)
%WRITEVIDEO Render a deterministic animation from Multibody joint logs.
arguments
    robot (1,1) struct
    multibodyRun (1,1) struct
    videoPath (1,1) string
    videoOptions (1,1) struct
end

validateInputs(robot,multibodyRun,videoOptions);
videoDirectory = fileparts(videoPath);
if strlength(videoDirectory) > 0 && ~isfolder(videoDirectory)
    mkdir(videoDirectory);
end

writer = VideoWriter(videoPath,videoOptions.format);
writer.FrameRate = videoOptions.frameRate;
open(writer);
writerCleanup = onCleanup(@() close(writer));
[figureHandle,graphics] = makeFigure(robot,videoOptions.frameSize);
figureCleanup = onCleanup(@() close(figureHandle));

duration = multibodyRun.time(end)-multibodyRun.time(1);
framePeriod = videoOptions.playbackSpeedRatio/videoOptions.frameRate;
frameTime = (multibodyRun.time(1):framePeriod:multibodyRun.time(end)).';
if frameTime(end) < multibodyRun.time(end)
    frameTime(end+1,1) = multibodyRun.time(end);
end
q = interp1(multibodyRun.time,multibodyRun.q.',frameTime,"linear").';
for frameIndex = 1:numel(frameTime)
    updateFigure(graphics,robot,q(:,frameIndex), ...
        frameTime(frameIndex),duration);
    drawnow;
    frame = getframe(figureHandle);
    expectedSize = videoOptions.frameSize([2 1]);
    if ~isequal(size(frame.cdata,[1 2]),expectedSize)
        frame.cdata = imresize(frame.cdata,expectedSize);
    end
    writer.writeVideo(frame);
end
clear writerCleanup figureCleanup

file = dir(videoPath);
if numel(file) ~= 1 || file.bytes == 0
    error("rrm:experiment:MultibodyVideoExportFailed", ...
        "Multibody log animation did not create a nonempty video file.");
end
end

function validateInputs(robot,run,videoOptions)
requiredRobot = ["L1","L2"];
requiredRun = ["time","q","status","completedSamples"];
requiredVideo = ["playbackSpeedRatio","frameRate","frameSize","format"];
validRun = all(isfield(run,requiredRun));
if validRun
    sampleCount = numel(run.time);
    validRun = isequal(size(run.time),[sampleCount 1]) && ...
        sampleCount >= 2 && isequal(size(run.q),[2 sampleCount]) && ...
        all(isfinite([run.time.';run.q]),"all") && ...
        all(diff(run.time) > 0) && run.status == "completed" && ...
        run.completedSamples == sampleCount;
end
validVideo = all(isfield(videoOptions,requiredVideo));
if validVideo
    validVideo = isscalar(videoOptions.playbackSpeedRatio) && ...
        isfinite(videoOptions.playbackSpeedRatio) && ...
        videoOptions.playbackSpeedRatio > 0 && ...
        isscalar(videoOptions.frameRate) && ...
        isfinite(videoOptions.frameRate) && videoOptions.frameRate > 0 && ...
        isequal(size(videoOptions.frameSize),[1 2]) && ...
        all(isfinite(videoOptions.frameSize)) && ...
        all(videoOptions.frameSize > 0) && ...
        all(videoOptions.frameSize == fix(videoOptions.frameSize)) && ...
        isstring(videoOptions.format) && isscalar(videoOptions.format);
end
if ~all(isfield(robot,requiredRobot)) || ...
        any(~isfinite([robot.L1 robot.L2])) || ...
        any([robot.L1 robot.L2] <= 0) || ~validRun || ~validVideo
    error("rrm:multibody:InvalidVideoInput", ...
        "Robot, Multibody run, or video options are invalid.");
end
end

function [figureHandle,graphics] = makeFigure(robot,frameSize)
figureHandle = figure("Visible","off","Color","white", ...
    "Units","pixels","Position",[50 50 frameSize], ...
    "MenuBar","none","ToolBar","none","Resize","off");
axisHandle = axes(figureHandle,"Position",[0.10 0.12 0.82 0.80]);
hold(axisHandle,"on");
graphics.link1 = patch(axisHandle,NaN,NaN,[0.18 0.48 0.78], ...
    "EdgeColor",[0.08 0.20 0.34],"LineWidth",1.5);
graphics.link2 = patch(axisHandle,NaN,NaN,[0.95 0.55 0.16], ...
    "EdgeColor",[0.45 0.22 0.05],"LineWidth",1.5);
graphics.joints = plot(axisHandle,NaN,NaN,"o", ...
    "MarkerFaceColor",[0.15 0.15 0.18],"MarkerEdgeColor","white", ...
    "MarkerSize",10,"LineWidth",1.2);
graphics.payload = plot(axisHandle,NaN,NaN,"o", ...
    "MarkerFaceColor",[0.55 0.12 0.62],"MarkerEdgeColor","white", ...
    "MarkerSize",16,"LineWidth",1.2);
plot(axisHandle,0,0,"s","MarkerFaceColor",[0.25 0.25 0.28], ...
    "MarkerEdgeColor","black","MarkerSize",16);
reach = robot.L1+robot.L2;
xlim(axisHandle,[-1.08 1.08]*reach);
ylim(axisHandle,[-1.08 1.08]*reach);
axis(axisHandle,"equal");
grid(axisHandle,"on");
xlabel(axisHandle,"x (m)");
ylabel(axisHandle,"y (m)");
title(axisHandle,"Torque-Driven Simscape Multibody Validation");
graphics.time = text(axisHandle,0.02,0.97,"", ...
    "Units","normalized","VerticalAlignment","top", ...
    "FontWeight","bold","FontSize",12);
graphics.width = 0.06;
end

function updateFigure(graphics,robot,q,time,duration)
p0 = [0;0];
p1 = [robot.L1*cos(q(1));robot.L1*sin(q(1))];
p2 = p1+[robot.L2*cos(sum(q));robot.L2*sin(sum(q))];
set(graphics.link1,"XData",linkCorners(p0,p1,graphics.width,0), ...
    "YData",linkCorners(p0,p1,graphics.width,1));
set(graphics.link2,"XData",linkCorners(p1,p2,graphics.width,0), ...
    "YData",linkCorners(p1,p2,graphics.width,1));
set(graphics.joints,"XData",[p0(1) p1(1)], ...
    "YData",[p0(2) p1(2)]);
set(graphics.payload,"XData",p2(1),"YData",p2(2));
set(graphics.time,"String",sprintf("Multibody time: %.2f / %.2f s", ...
    time,duration));
end

function coordinate = linkCorners(startPoint,endPoint,width,useY)
direction = endPoint-startPoint;
normal = width/2*[-direction(2);direction(1)]/norm(direction);
corners = [startPoint+normal endPoint+normal ...
    endPoint-normal startPoint-normal];
coordinate = corners(useY+1,:);
end
