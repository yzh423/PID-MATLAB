classdef TestFuzzyPidStep < matlab.unittest.TestCase
    methods (Test)
        function gainsAndFuzzySignalsRemainBounded(testCase)
            [robot, controller, state] = fixtures();
            [tau, nextState, diagnostic] = rrm.control.fuzzyPidStep( ...
                controller, robot, deg2rad([15;-12]), deg2rad([20;-30]), ...
                [0;0], [0;0], state, 0.001);

            testCase.verifyLessThanOrEqual(abs(tau), robot.torqueLimits);
            testCase.verifySize(nextState.integral, [2 1]);
            testCase.verifySize(diagnostic.fuzzyCorrection, [3 2]);
            testCase.verifyLessThanOrEqual( ...
                abs(diagnostic.normalizedError), 1+1e-14);
            testCase.verifyLessThanOrEqual( ...
                abs(diagnostic.normalizedRate), 1+1e-14);
            testCase.verifyLessThanOrEqual( ...
                abs(diagnostic.fuzzyCorrection), 1+1e-14);
            verifyGainBounds(testCase, controller, diagnostic);
        end

        function saturationAndAntiWindupArePreserved(testCase)
            [robot, controller, state] = fixtures();
            [tau, nextState, diagnostic] = rrm.control.fuzzyPidStep( ...
                controller, robot, [10;10], [0;0], [0;0], [0;0], ...
                state, 0.001);

            testCase.verifyTrue(any(diagnostic.saturated));
            testCase.verifyLessThanOrEqual(abs(tau), robot.torqueLimits);
            testCase.verifyLessThan(norm(nextState.integral), ...
                norm([10;10])*0.001);
            verifyGainBounds(testCase, controller, diagnostic);
        end

        function zeroErrorUpdateIsFinite(testCase)
            [robot, controller, state] = fixtures();
            [tau, nextState, diagnostic] = rrm.control.fuzzyPidStep( ...
                controller, robot, [0;0], [0;0], [0;0], [0;0], ...
                state, 0.001);

            testCase.verifyEqual(tau, [0;0], AbsTol=1e-14);
            testCase.verifyTrue(all(isfinite(nextState.integral)));
            testCase.verifyTrue(all(isfinite(diagnostic.fuzzyCorrection), "all"));
        end
    end
end

function [robot, controller, state] = fixtures()
robot = rrm.config.makeRobot("baseline");
controller = rrm.config.makeFuzzyPidController(robot);
state = struct("integral",[0;0],"filteredDerivative",[0;0]);
end

function verifyGainBounds(testCase, controller, diagnostic)
gainNames = ["Kp","Ki","Kd"];
for gainName = gainNames
    effective = diagnostic.("effective" + gainName);
    testCase.verifyGreaterThanOrEqual( ...
        effective, controller.gainBounds.lower.(gainName)-1e-14);
    testCase.verifyLessThanOrEqual( ...
        effective, controller.gainBounds.upper.(gainName)+1e-14);
end
end
