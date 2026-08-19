classdef TestKinematics < matlab.unittest.TestCase
    methods (Test)
        function forwardAtZeroIsFullyExtended(testCase)
            robot = rrm.config.makeRobot("baseline");
            position = rrm.kinematics.forward(robot, [0; 0]);

            testCase.verifyEqual( ...
                position, [robot.L1 + robot.L2; 0], AbsTol=1e-12);
        end

        function inverseRoundTripReturnsBothBranches(testCase)
            robot = rrm.config.makeRobot("baseline");
            expectedPosition = rrm.kinematics.forward( ...
                robot, deg2rad([35; -50]));

            [solutions, reachable] = rrm.kinematics.inverse( ...
                robot, expectedPosition);

            testCase.verifyTrue(reachable);
            testCase.verifySize(solutions, [2 2]);
            for branch = 1:2
                actualPosition = rrm.kinematics.forward( ...
                    robot, solutions(:, branch));
                testCase.verifyEqual( ...
                    actualPosition, expectedPosition, AbsTol=1e-10);
            end
        end

        function unreachableTargetIsReported(testCase)
            robot = rrm.config.makeRobot("baseline");
            [solutions, reachable] = rrm.kinematics.inverse(robot, [2; 0]);

            testCase.verifyFalse(reachable);
            testCase.verifyTrue(all(isnan(solutions), "all"));
        end

        function malformedJointVectorIsRejected(testCase)
            robot = rrm.config.makeRobot("baseline");
            testCase.verifyError( ...
                @() rrm.kinematics.forward(robot, [0 0]), ...
                "MATLAB:validation:IncompatibleSize");
        end
    end
end
