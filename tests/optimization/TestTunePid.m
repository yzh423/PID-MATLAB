classdef TestTunePid < matlab.unittest.TestCase
    methods (Test)
        function boundedRealSolverRunIsDeterministic(testCase)
            [robot, controller, reference, options, configuration] = fixtures();
            first = rrm.optimization.tunePid( ...
                robot, controller, reference, options, configuration);
            second = rrm.optimization.tunePid( ...
                robot, controller, reference, options, configuration);

            testCase.verifyTrue(isfinite(first.initialObjective));
            testCase.verifyTrue(isfinite(first.finalObjective));
            testCase.verifyGreaterThanOrEqual( ...
                first.finalMultipliers, configuration.lowerBounds-1e-12);
            testCase.verifyLessThanOrEqual( ...
                first.finalMultipliers, configuration.upperBounds+1e-12);
            testCase.verifyNotEmpty(first.history);
            testCase.verifyGreaterThanOrEqual(numel(first.history), 2);
            testCase.verifyEqual(first.finalResult.status, "completed");
            testCase.verifyEqual(first.finalComponents.total, ...
                first.finalObjective, AbsTol=1e-14);
            testCase.verifyEqual(first.finalMultipliers, ...
                second.finalMultipliers, AbsTol=1e-10);
            testCase.verifyEqual(first.finalObjective, ...
                second.finalObjective, AbsTol=1e-10);
            testCase.verifyEqual(first.controller.Kp, ...
                controller.Kp.*first.finalMultipliers(1:2));
        end
    end
end

function [robot, controller, reference, options, configuration] = fixtures()
robot = rrm.config.makeRobot("baseline");
controller = rrm.config.makePidController(robot);
options = rrm.config.makeSimulationOptions();
options.sampleTime = 0.005;
reference = rrm.trajectory.quintic( ...
    [0;0], deg2rad([2;3]), 0.15, options.sampleTime, 0.20);
configuration = rrm.config.makePidOptimization(controller);
configuration.solver.maxIterations = 2;
configuration.solver.maxFunctionEvaluations = 12;
configuration.solver.display = "off";
end
