classdef TestMakePidOptimization < matlab.unittest.TestCase
    methods (Test)
        function definesReproducibleDecisionAndObjectiveConfiguration(testCase)
            robot = rrm.config.makeRobot("baseline");
            controller = rrm.config.makePidController(robot);
            configuration = rrm.config.makePidOptimization(controller);

            testCase.verifyEqual(configuration.variableOrder, ...
                ["Kp1";"Kp2";"Ki1";"Ki2";"Kd1";"Kd2"]);
            testCase.verifyEqual(configuration.initialMultipliers, ones(6,1));
            testCase.verifyEqual(configuration.lowerBounds, ...
                [0.5;0.5;0.25;0.25;0.5;0.5]);
            testCase.verifyEqual(configuration.upperBounds, 2*ones(6,1));
            testCase.verifyEqual(configuration.objectiveWeights, ...
                struct("trackingRms",0.50,"overshoot",0.10, ...
                "torqueRms",0.15,"settlingTime",0.25));
            testCase.verifyEqual(configuration.saturationPenalty, 100);
            testCase.verifyEqual(configuration.failurePenalty, 100);
            testCase.verifyEqual(configuration.settlingBand, deg2rad(2));
        end

        function definesSerializableSqpSettings(testCase)
            controller = rrm.config.makePidController( ...
                rrm.config.makeRobot("baseline"));
            configuration = rrm.config.makePidOptimization(controller);

            testCase.verifyEqual(configuration.solver.algorithm, "sqp");
            testCase.verifyEqual(configuration.solver.maxIterations, 20);
            testCase.verifyEqual( ...
                configuration.solver.maxFunctionEvaluations, 150);
            testCase.verifyEqual(configuration.solver.stepTolerance, 1e-4);
            testCase.verifyEqual( ...
                configuration.solver.optimalityTolerance, 1e-3);
            testCase.verifyEqual( ...
                configuration.solver.finiteDifferenceType, "forward");
            testCase.verifyFalse(configuration.solver.useParallel);
            testCase.verifyTrue(isstruct(configuration.solver));
        end
    end
end
