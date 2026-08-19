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

        function explicitEffectiveGainsPreserveLegacyResult(testCase)
            robot = rrm.config.makeRobot("baseline");
            controller = rrm.config.makePidController(robot);
            state = struct( ...
                "integral", [0.1;-0.2], ...
                "filteredDerivative", [0.3;-0.4]);
            inputs = {controller, robot, [0.5;-0.3], [0.2;0.1], ...
                [0.1;-0.1], [-0.2;0.3], state, 0.001};

            [legacyTau, legacyState, legacyDiagnostic] = ...
                rrm.control.pidStep(inputs{:});
            gains = struct("Kp",controller.Kp, ...
                "Ki",controller.Ki,"Kd",controller.Kd);
            [explicitTau, explicitState, explicitDiagnostic] = ...
                rrm.control.pidStep(inputs{:}, gains);

            testCase.verifyEqual(explicitTau, legacyTau, AbsTol=0);
            testCase.verifyEqual(explicitState, legacyState);
            testCase.verifyEqual( ...
                explicitDiagnostic.unsaturatedTorque, ...
                legacyDiagnostic.unsaturatedTorque, AbsTol=0);
            testCase.verifyEqual(explicitDiagnostic.effectiveKp, controller.Kp);
            testCase.verifyEqual(explicitDiagnostic.effectiveKi, controller.Ki);
            testCase.verifyEqual(explicitDiagnostic.effectiveKd, controller.Kd);
        end

        function controllerDeclaresPidType(testCase)
            controller = rrm.config.makePidController( ...
                rrm.config.makeRobot("baseline"));
            testCase.verifyEqual(controller.type, "pid");
        end
    end
end
