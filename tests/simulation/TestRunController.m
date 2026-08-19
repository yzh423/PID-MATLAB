classdef TestRunController < matlab.unittest.TestCase
    methods (Test)
        function pidWrapperAndGenericPathAreIdentical(testCase)
            [robot, options, reference] = fixtures();
            controller = rrm.config.makePidController(robot);

            wrapperResult = rrm.simulation.runPid( ...
                robot, controller, reference, options);
            genericResult = rrm.simulation.runController( ...
                robot, controller, reference, options);

            testCase.verifyEqual(genericResult, wrapperResult);
            testCase.verifyEqual(genericResult.effectiveKp, ...
                repmat(controller.Kp, 1, numel(reference.time)));
        end

        function fuzzyRunCompletesWithCommonReferenceAndBoundedGains(testCase)
            [robot, options, reference] = fixtures();
            controller = rrm.config.makeFuzzyPidController(robot);
            result = rrm.simulation.runFuzzyPid( ...
                robot, controller, reference, options);

            sampleCount = numel(reference.time);
            testCase.verifyEqual(result.status, "completed");
            testCase.verifyEqual(result.time, reference.time);
            testCase.verifyEqual(result.qReference, reference.q);
            testCase.verifySize(result.effectiveKp, [2 sampleCount]);
            testCase.verifySize(result.effectiveKi, [2 sampleCount]);
            testCase.verifySize(result.effectiveKd, [2 sampleCount]);
            testCase.verifySize(result.fuzzyCorrection, [3 2 sampleCount]);
            testCase.verifyTrue(all(isfinite(result.q), "all"));
            testCase.verifyTrue(all(isfinite(result.tau), "all"));
            verifyHistoryBounds(testCase, result, controller);
        end

        function unknownControllerTypeIsRejected(testCase)
            [robot, options, reference] = fixtures();
            controller = rrm.config.makePidController(robot);
            controller.type = "unsupported";

            testCase.verifyError(@() rrm.simulation.runController( ...
                robot, controller, reference, options), ...
                "rrm:simulation:UnknownControllerType");
        end
    end
end

function [robot, options, reference] = fixtures()
robot = rrm.config.makeRobot("baseline");
options = rrm.config.makeSimulationOptions();
reference = rrm.trajectory.quintic( ...
    [0;0], deg2rad([10;15]), 0.8, options.sampleTime, 1.2);
end

function verifyHistoryBounds(testCase, result, controller)
gainNames = ["Kp","Ki","Kd"];
for gainName = gainNames
    history = result.("effective" + gainName);
    testCase.verifyGreaterThanOrEqual( ...
        history, controller.gainBounds.lower.(gainName)-1e-12);
    testCase.verifyLessThanOrEqual( ...
        history, controller.gainBounds.upper.(gainName)+1e-12);
end
end
