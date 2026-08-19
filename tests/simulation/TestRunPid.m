classdef TestRunPid < matlab.unittest.TestCase
    methods (Test)
        function nominalRunIsFiniteAndRespectsHardLimits(testCase)
            robot = rrm.config.makeRobot("baseline");
            controller = rrm.config.makePidController(robot);
            options = rrm.config.makeSimulationOptions();
            reference = rrm.trajectory.quintic( ...
                [0;0], deg2rad([45;60]), 3, options.sampleTime, 5);

            result = rrm.simulation.runPid( ...
                robot, controller, reference, options);

            sampleCount = numel(reference.time);
            testCase.verifyEqual(result.status, "completed");
            testCase.verifySize(result.q, [2 sampleCount]);
            testCase.verifySize(result.dq, [2 sampleCount]);
            testCase.verifySize(result.tau, [2 sampleCount]);
            testCase.verifySize(result.effectiveKp, [2 sampleCount]);
            testCase.verifySize(result.effectiveKi, [2 sampleCount]);
            testCase.verifySize(result.effectiveKd, [2 sampleCount]);
            testCase.verifyTrue(all(isfinite(result.q), "all"));
            testCase.verifyTrue(all(isfinite(result.dq), "all"));
            testCase.verifyTrue(all(isfinite(result.tau), "all"));
            testCase.verifyLessThanOrEqual( ...
                max(abs(result.tau), [], 2), robot.torqueLimits + 1e-12);
            testCase.verifyGreaterThanOrEqual( ...
                min(result.q, [], 2), robot.jointLimits(:,1) - 1e-12);
            testCase.verifyLessThanOrEqual( ...
                max(result.q, [], 2), robot.jointLimits(:,2) + 1e-12);
        end
    end
end
