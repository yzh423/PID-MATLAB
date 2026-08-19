classdef TestMakeStochasticScenarios < matlab.unittest.TestCase
    methods (Test)
        function fullModeHasExactNamesSeedsAndNoiseLevels(testCase)
            [reference, options] = fixtures();
            scenarios = rrm.robustness.makeStochasticScenarios( ...
                reference, options, "full");

            testCase.verifyEqual([scenarios.name], ...
                ["noise-low","noise-medium","noise-high", ...
                "combined-stochastic"]);
            testCase.verifyEqual([scenarios.category], ...
                ["noise","noise","noise","combined"]);
            for index = 1:numel(scenarios)
                testCase.verifyEqual(scenarios(index).seeds, 42001:42030);
            end
            position = [scenarios(1:3).noise];
            testCase.verifyEqual([position.positionStd], ...
                deg2rad([0.05 0.20 0.50;0.05 0.20 0.50]));
            testCase.verifyEqual([position.velocityStd], ...
                deg2rad([0.5 2.0 5.0;0.5 2.0 5.0]));
        end

        function combinedCaseMatchesFinalStressDefinition(testCase)
            [reference, options] = fixtures();
            scenarios = rrm.robustness.makeStochasticScenarios( ...
                reference, options, "full");
            combined = scenarios(4);
            unscaled = rrm.config.makeRobot("extended");
            active = reference.time >= 2.00 & reference.time <= 2.10;

            testCase.verifyEqual([combined.robot.L1 combined.robot.L2], ...
                [0.55 0.45]);
            testCase.verifyEqual(combined.robot.payload, 1.0);
            testCase.verifyEqual([combined.robot.m1;combined.robot.m2; ...
                combined.robot.inertia], ...
                1.2*[unscaled.m1;unscaled.m2;unscaled.inertia]);
            testCase.verifyEqual(combined.robot.torqueLimits, [18;10]);
            testCase.verifyEqual(combined.noise.positionStd, ...
                deg2rad([0.2;0.2]));
            testCase.verifyEqual(combined.noise.velocityStd, ...
                deg2rad([2;2]));
            testCase.verifyEqual(combined.disturbanceWindow, [2;2.1]);
            testCase.verifyEqual( ...
                combined.options.disturbanceTorque(:,active), ...
                repmat([4;-3],1,nnz(active)));
            testCase.verifyEqual( ...
                combined.options.disturbanceTorque(:,~active), ...
                zeros(2,nnz(~active)));
        end

        function smokeModeUsesTwoScenariosAndTwoSeeds(testCase)
            [reference, options] = fixtures();
            scenarios = rrm.robustness.makeStochasticScenarios( ...
                reference, options, "smoke");
            testCase.verifyEqual([scenarios.name], ...
                ["noise-medium","combined-stochastic"]);
            testCase.verifyEqual(scenarios(1).seeds, 42001:42002);
            testCase.verifyEqual(scenarios(2).seeds, 42001:42002);
        end
    end
end

function [reference, options] = fixtures()
options = rrm.config.makeSimulationOptions();
reference = rrm.trajectory.quintic( ...
    [0;0],deg2rad([45;60]),3,options.sampleTime,5);
end
