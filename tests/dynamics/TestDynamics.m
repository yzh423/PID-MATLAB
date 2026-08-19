classdef TestDynamics < matlab.unittest.TestCase
    methods (Test)
        function inertiaIsSymmetricPositiveDefinite(testCase)
            robot = rrm.config.makeRobot("baseline");
            for q2 = linspace(-pi, pi, 9)
                [M, ~, ~] = rrm.dynamics.matrices( ...
                    robot, [0.4; q2], [0.2; -0.1]);
                testCase.verifyEqual(M, M.', AbsTol=1e-12);
                testCase.verifyGreaterThan(eig(M), 0);
            end
        end

        function coriolisIsZeroAtRest(testCase)
            robot = rrm.config.makeRobot("baseline");
            [~, C, ~] = rrm.dynamics.matrices( ...
                robot, [0.4; -0.2], [0; 0]);
            testCase.verifyEqual(C, zeros(2), AbsTol=1e-14);
        end

        function gravityCompensationHoldsAtRest(testCase)
            robot = rrm.config.makeRobot("baseline");
            q = [0.5; -0.3];
            [~, ~, gravityTorque] = rrm.dynamics.matrices( ...
                robot, q, [0; 0]);

            ddq = rrm.dynamics.acceleration( ...
                robot, q, [0; 0], gravityTorque, [0; 0]);

            testCase.verifyLessThan(norm(ddq), 1e-10);
        end

        function endpointPayloadIncreasesInertiaAndGravity(testCase)
            robot = rrm.config.makeRobot("baseline");
            unloaded = robot;
            unloaded.payload = 0;

            [MLoaded, ~, GLoaded] = rrm.dynamics.matrices( ...
                robot, [0; 0], [0; 0]);
            [MUnloaded, ~, GUnloaded] = rrm.dynamics.matrices( ...
                unloaded, [0; 0], [0; 0]);

            testCase.verifyGreaterThan(MLoaded(1,1), MUnloaded(1,1));
            testCase.verifyGreaterThan(MLoaded(2,2), MUnloaded(2,2));
            testCase.verifyGreaterThan(GLoaded, GUnloaded);
        end
    end
end
