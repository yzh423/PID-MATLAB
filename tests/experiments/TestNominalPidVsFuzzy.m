classdef TestNominalPidVsFuzzy < matlab.unittest.TestCase
    methods (Test)
        function createsAcceptedFairComparisonArtifacts(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            outputRoot = tempname;
            mkdir(outputRoot);
            testCase.addTeardown(@() rmdir(outputRoot, "s"));

            run(fullfile(projectRoot, "experiments", ...
                "run_nominal_pid_vs_fuzzy.m"));

            dataFile = fullfile(outputRoot, "data", ...
                "nominal_pid_vs_fuzzy.mat");
            testCase.verifyEqual(exist(dataFile, "file"), 2);
            figureNames = ["tracking", "error", "torque", "gains"];
            for figureName = figureNames
                figureFile = fullfile(outputRoot, "figures", ...
                    "nominal_pid_vs_fuzzy_" + figureName + ".png");
                testCase.verifyEqual(exist(figureFile, "file"), 2);
            end

            saved = load(dataFile);
            testCase.verifyEqual(saved.pidResult.time, saved.fuzzyResult.time);
            testCase.verifyEqual( ...
                saved.pidResult.qReference, saved.fuzzyResult.qReference);
            testCase.verifyEqual(saved.pidResult.status, "completed");
            testCase.verifyEqual(saved.fuzzyResult.status, "completed");
            testCase.verifyTrue(saved.pidMetrics.success);
            testCase.verifyTrue(saved.fuzzyMetrics.success);
            testCase.verifyEqual(saved.fuzzyMetrics.saturationTime, [0;0]);
            testCase.verifyLessThan( ...
                saved.fuzzyMetrics.steadyStateRmsError, [0.02;0.02]);
            testCase.verifyLessThan( ...
                saved.fuzzyMetrics.steadyStateMaxAbsError, [0.05;0.05]);
            testCase.verifyLessThanOrEqual( ...
                max(abs(saved.pidResult.tau),[],2), ...
                saved.robot.torqueLimits+1e-12);
            testCase.verifyLessThanOrEqual( ...
                max(abs(saved.fuzzyResult.tau),[],2), ...
                saved.robot.torqueLimits+1e-12);
        end
    end
end
