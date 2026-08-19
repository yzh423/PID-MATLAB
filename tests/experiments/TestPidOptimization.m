classdef TestPidOptimization < matlab.unittest.TestCase
    methods (Test)
        function createsReproducibleOptimizationAndValidationEvidence(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            outputRoot = tempname;
            mkdir(outputRoot);
            testCase.addTeardown(@() rmdir(outputRoot,"s"));

            run(fullfile(projectRoot,"experiments","run_pid_optimization.m"));

            dataFile = fullfile(outputRoot,"data","pid_optimization.mat");
            testCase.verifyEqual(exist(dataFile,"file"),2);
            figureNames = ["objective","nominal_tracking","nominal_torque", ...
                "validation_tracking","gains"];
            for figureName = figureNames
                testCase.verifyEqual(exist(fullfile(outputRoot,"figures", ...
                    "pid_optimization_" + figureName + ".png"),"file"),2);
            end

            saved = load(dataFile);
            testCase.verifyEqual(saved.trainingRobot.payload,0.5);
            testCase.verifyEqual(saved.validationRobot.payload,0.8);
            testCase.verifyEqual(saved.nominalManualResult.qReference, ...
                saved.nominalOptimizedResult.qReference);
            testCase.verifyEqual(saved.validationManualResult.qReference, ...
                saved.validationOptimizedResult.qReference);
            testCase.verifyLessThanOrEqual(saved.nominalOptimizedObjective, ...
                0.98*saved.nominalManualObjective);
            testCase.verifyTrue(saved.nominalOptimizedMetrics.success);
            testCase.verifyEqual(saved.nominalOptimizedMetrics.saturationTime,[0;0]);
            testCase.verifyTrue(saved.validationOptimizedMetrics.success);
            testCase.verifyEqual(saved.validationOptimizedMetrics.saturationTime,[0;0]);
            errorRatio = mean(saved.validationOptimizedMetrics.rmsError) / ...
                mean(saved.validationManualMetrics.rmsError);
            testCase.verifyLessThanOrEqual(errorRatio,1.10);
            testCase.verifyGreaterThanOrEqual( ...
                saved.optimizationReport.finalMultipliers, ...
                saved.optimizationConfiguration.lowerBounds-1e-12);
            testCase.verifyLessThanOrEqual( ...
                saved.optimizationReport.finalMultipliers, ...
                saved.optimizationConfiguration.upperBounds+1e-12);
        end
    end
end
