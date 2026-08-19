classdef TestApplyPidMultipliers < matlab.unittest.TestCase
    methods (Test)
        function mapsDocumentedOrderAndPreservesControllerSettings(testCase)
            [baseController, configuration] = fixtures();
            multipliers = [2;0.5;1.5;0.25;1;2];
            tuned = rrm.optimization.applyPidMultipliers( ...
                baseController, multipliers, configuration);

            testCase.verifyEqual(tuned.name, "optimized-pid");
            testCase.verifyEqual(tuned.type, baseController.type);
            testCase.verifyEqual(tuned.Kp, baseController.Kp.*[2;0.5]);
            testCase.verifyEqual(tuned.Ki, baseController.Ki.*[1.5;0.25]);
            testCase.verifyEqual(tuned.Kd, baseController.Kd.*[1;2]);
            testCase.verifyEqual( ...
                tuned.derivativeFilterHz, baseController.derivativeFilterHz);
            testCase.verifyEqual( ...
                tuned.antiWindupGain, baseController.antiWindupGain);
            testCase.verifyEqual(tuned.torqueLimits, baseController.torqueLimits);
        end

        function rejectsMalformedAndOutOfBoundVectors(testCase)
            [baseController, configuration] = fixtures();
            testCase.verifyError(@() rrm.optimization.applyPidMultipliers( ...
                baseController, ones(5,1), configuration), ...
                "rrm:optimization:InvalidMultipliers");
            testCase.verifyError(@() rrm.optimization.applyPidMultipliers( ...
                baseController, [0.4;ones(5,1)], configuration), ...
                "rrm:optimization:MultiplierOutOfBounds");
            testCase.verifyError(@() rrm.optimization.applyPidMultipliers( ...
                baseController, [NaN;ones(5,1)], configuration), ...
                "rrm:optimization:InvalidMultipliers");
        end
    end
end

function [controller, configuration] = fixtures()
controller = rrm.config.makePidController( ...
    rrm.config.makeRobot("baseline"));
configuration = rrm.config.makePidOptimization(controller);
end
