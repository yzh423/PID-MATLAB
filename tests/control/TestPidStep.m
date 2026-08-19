classdef TestPidStep < matlab.unittest.TestCase
    methods (Test)
        function saturationIsAppliedAndRecorded(testCase)
            robot = rrm.config.makeRobot("baseline");
            controller = rrm.config.makePidController(robot);
            state = struct( ...
                "integral", [0; 0], ...
                "filteredDerivative", [0; 0]);

            [tau, nextState, diagnostic] = rrm.control.pidStep( ...
                controller, robot, [10; 10], [0; 0], [0; 0], [0; 0], ...
                state, 0.001);

            testCase.verifyLessThanOrEqual(abs(tau), robot.torqueLimits);
            testCase.verifyTrue(any(diagnostic.saturated));
            testCase.verifySize(nextState.integral, [2 1]);
            testCase.verifyLessThan( ...
                norm(nextState.integral), norm([10;10])*0.001);
        end

        function zeroErrorProducesZeroTorque(testCase)
            robot = rrm.config.makeRobot("baseline");
            controller = rrm.config.makePidController(robot);
            state = struct( ...
                "integral", [0; 0], ...
                "filteredDerivative", [0; 0]);

            [tau, nextState, diagnostic] = rrm.control.pidStep( ...
                controller, robot, [0; 0], [0; 0], [0; 0], [0; 0], ...
                state, 0.001);

            testCase.verifyEqual(tau, [0; 0], AbsTol=1e-14);
            testCase.verifyEqual(nextState.integral, [0; 0], AbsTol=1e-14);
            testCase.verifyFalse(any(diagnostic.saturated));
        end
    end
end
