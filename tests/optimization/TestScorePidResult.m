classdef TestScorePidResult < matlab.unittest.TestCase
    methods (Test)
        function exactTrackingHasOnlyDocumentedSettlingContribution(testCase)
            [result, robot, reference, configuration] = fixtures();
            [objective, components] = rrm.optimization.scorePidResult( ...
                result, robot, reference, configuration);

            testCase.verifyEqual(components.trackingRms, 0, AbsTol=1e-14);
            testCase.verifyEqual(components.overshoot, 0, AbsTol=1e-14);
            testCase.verifyEqual(components.torqueRms, 0, AbsTol=1e-14);
            testCase.verifyEqual(components.settlingTime, 1, AbsTol=1e-14);
            testCase.verifyEqual(components.saturationFraction, 0);
            testCase.verifyEqual(components.failurePenalty, 0);
            testCase.verifyEqual(components.weighted, [0;0;0;0.25]);
            testCase.verifyEqual(objective, 0.25, AbsTol=1e-14);
            testCase.verifyEqual(components.total, objective);
        end

        function directionalOvershootHandlesIncreasingAndDecreasingJoints(testCase)
            [result, robot, reference, configuration] = fixtures();
            result.q(1,end) = 1.1;
            result.q(2,end) = -2.2;
            [~, components] = rrm.optimization.scorePidResult( ...
                result, robot, reference, configuration);
            testCase.verifyEqual(components.overshoot, 0.1, AbsTol=1e-14);
        end

        function saturationAndFailurePenaltiesAreExact(testCase)
            [result, robot, reference, configuration] = fixtures();
            baseline = rrm.optimization.scorePidResult( ...
                result, robot, reference, configuration);

            saturated = result;
            saturated.saturated(:) = true;
            saturatedScore = rrm.optimization.scorePidResult( ...
                saturated, robot, reference, configuration);
            testCase.verifyEqual(saturatedScore-baseline, 100, AbsTol=1e-14);

            failed = result;
            failed.status = "joint-limit-violation";
            failedScore = rrm.optimization.scorePidResult( ...
                failed, robot, reference, configuration);
            testCase.verifyEqual(failedScore-baseline, 100, AbsTol=1e-14);
        end

        function partiallyInvalidFailureReceivesFiniteMissingSamplePenalty(testCase)
            [result, robot, reference, configuration] = fixtures();
            result.status = "non-finite-state";
            result.completedSamples = 4;
            result.q(:,end) = NaN;
            result.tau(:,end) = NaN;
            [objective, components] = rrm.optimization.scorePidResult( ...
                result, robot, reference, configuration);

            testCase.verifyTrue(isfinite(objective));
            testCase.verifyEqual(components.failurePenalty, 120, AbsTol=1e-12);
        end

        function zeroCommandedTravelIsRejected(testCase)
            [result, robot, reference, configuration] = fixtures();
            reference.q(1,:) = 0;
            result.qReference = reference.q;
            testCase.verifyError(@() rrm.optimization.scorePidResult( ...
                result, robot, reference, configuration), ...
                "rrm:optimization:ZeroTravel");
        end
    end
end

function [result, robot, reference, configuration] = fixtures()
robot = rrm.config.makeRobot("baseline");
controller = rrm.config.makePidController(robot);
configuration = rrm.config.makePidOptimization(controller);
reference = struct( ...
    "time", (0:4).', ...
    "q", [linspace(0,1,5);linspace(0,-2,5)], ...
    "dq", zeros(2,5), ...
    "ddq", zeros(2,5));
result = struct( ...
    "time", reference.time, ...
    "q", reference.q, ...
    "qReference", reference.q, ...
    "tau", zeros(2,5), ...
    "saturated", false(2,5), ...
    "status", "completed", ...
    "completedSamples", 5);
end
