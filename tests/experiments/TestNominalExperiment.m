classdef TestNominalExperiment < matlab.unittest.TestCase
    methods (Test)
        function createsReproducibleDataAndFigures(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            outputRoot = tempname;
            mkdir(outputRoot);
            testCase.addTeardown(@() rmdir(outputRoot, "s"));

            run(fullfile(projectRoot, "experiments", "run_nominal_pid.m"));

            testCase.verifyEqual( ...
                exist(fullfile(outputRoot, "data", "nominal_pid.mat"), "file"), 2);
            testCase.verifyEqual( ...
                exist(fullfile(outputRoot, "figures", ...
                    "nominal_pid_tracking.png"), "file"), 2);
            testCase.verifyEqual( ...
                exist(fullfile(outputRoot, "figures", ...
                    "nominal_pid_torque.png"), "file"), 2);

            savedResult = load(fullfile(outputRoot, "data", "nominal_pid.mat"));
            testCase.verifyTrue(savedResult.metrics.success);
            testCase.verifyEqual(savedResult.result.status, "completed");
        end
    end
end
