classdef TestWriteVideo < matlab.unittest.TestCase
    methods (Test)
        function shortRunCreatesNonemptyVideo(testCase)
            robot = rrm.config.makeRobot("baseline");
            controller = rrm.config.makePidController(robot);
            options = rrm.config.makeSimulationOptions();
            reference = rrm.trajectory.quintic( ...
                [0;0],deg2rad([2;3]),0.10,options.sampleTime,0.20);
            modelPath = fullfile("models", ...
                "rrm_multibody_cross_validation.slx");
            multibodyRun = rrm.multibody.runCrossValidation( ...
                robot,controller,reference,options,modelPath);
            videoPath = string(tempname)+".mp4";
            testCase.addTeardown(@() deleteIfPresent(videoPath));
            videoOptions = struct( ...
                "playbackSpeedRatio",1, ...
                "frameRate",10, ...
                "frameSize",[320 240], ...
                "format","MPEG-4");

            rrm.multibody.writeVideo( ...
                robot,multibodyRun,videoPath,videoOptions);

            file = dir(videoPath);
            testCase.verifyEqual(numel(file),1);
            testCase.verifyGreaterThan(file.bytes,0);
            reader = VideoReader(videoPath);
            testCase.verifyEqual([reader.Width reader.Height], ...
                videoOptions.frameSize);
            testCase.verifyEqual(reader.FrameRate,videoOptions.frameRate, ...
                "AbsTol",0.01);
        end
    end
end

function deleteIfPresent(path)
if isfile(path)
    delete(path);
end
end
