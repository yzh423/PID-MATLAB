classdef TestRunDeterministicMatrix < matlab.unittest.TestCase
    methods (Test)
        function createsEveryControllerScenarioPairOnce(testCase)
            options = rrm.config.makeSimulationOptions();
            reference = rrm.trajectory.quintic( ...
                [0;0], deg2rad([5;8]), 0.08, options.sampleTime, 0.12);
            scenarios = rrm.robustness.makeDeterministicScenarios( ...
                reference, options, "smoke");
            scenarios = scenarios([1 3]);
            robot = rrm.config.makeRobot("baseline");
            definitions(1) = struct("name", "manual-pid", ...
                "controller", rrm.config.makePidController(robot));
            definitions(2) = struct("name", "optimization-pid", ...
                "controller", rrm.config.makeOptimizedPidController(robot));

            matrix = rrm.robustness.runDeterministicMatrix( ...
                definitions, scenarios, reference, options.successCriteria);

            testCase.verifyEqual(height(matrix.table), 4);
            pairs = matrix.table.Scenario + "|" + matrix.table.Controller;
            testCase.verifyEqual(numel(unique(pairs)), 4);
            testCase.verifyEqual(numel(matrix.runs), 4);
            for index = 1:numel(matrix.runs)
                testCase.verifyEqual( ...
                    matrix.runs(index).result.qReference, reference.q);
                testCase.verifyNotEmpty(matrix.runs(index).result.status);
                testCase.verifyEqual(matrix.runs(index).scenario.name, ...
                    matrix.table.Scenario(index));
            end
        end

        function duplicateControllerLabelsAreRejected(testCase)
            options = rrm.config.makeSimulationOptions();
            reference = rrm.trajectory.quintic( ...
                [0;0], [0.1;0.1], 0.08, options.sampleTime, 0.12);
            scenarios = rrm.robustness.makeDeterministicScenarios( ...
                reference, options, "smoke");
            controller = rrm.config.makePidController( ...
                rrm.config.makeRobot("baseline"));
            definitions = repmat(struct("name", "duplicate", ...
                "controller", controller), 1, 2);
            testCase.verifyError(@() ...
                rrm.robustness.runDeterministicMatrix(definitions, ...
                scenarios(1), reference, options.successCriteria), ...
                "rrm:robustness:InvalidControllerDefinitions");
        end
    end
end
