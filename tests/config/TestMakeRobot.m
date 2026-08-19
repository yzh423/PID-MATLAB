classdef TestMakeRobot < matlab.unittest.TestCase
    methods (Test)
        function baselineHasConsistentPhysicalParameters(testCase)
            robot = rrm.config.makeRobot("baseline");

            testCase.verifyEqual(robot.name, "baseline");
            testCase.verifyGreaterThan( ...
                [robot.L1 robot.L2 robot.m1 robot.m2 robot.payload], 0);
            testCase.verifyEqual( ...
                robot.com, [robot.L1; robot.L2] / 2, AbsTol=1e-14);
            testCase.verifyEqual( ...
                robot.inertia, ...
                [robot.m1*robot.L1^2/12; robot.m2*robot.L2^2/12], ...
                AbsTol=1e-14);
            testCase.verifySize(robot.jointLimits, [2 2]);
            testCase.verifySize(robot.torqueLimits, [2 1]);
            testCase.verifyLessThan(robot.jointLimits(:,1), robot.jointLimits(:,2));
            testCase.verifyGreaterThan(robot.torqueLimits, 0);
        end

        function unsupportedConfigurationIsRejected(testCase)
            testCase.verifyError( ...
                @() rrm.config.makeRobot("unknown"), ...
                "MATLAB:validators:mustBeMember");
        end

        function prescribedConfigurationsRecomputeGeometry(testCase)
            compact = rrm.config.makeRobot("compact");
            extended = rrm.config.makeRobot("extended");

            testCase.verifyEqual([compact.L1 compact.L2],[0.35 0.25]);
            testCase.verifyEqual([extended.L1 extended.L2],[0.55 0.45]);
            testCase.verifyLessThan(compact.inertia,extended.inertia);
            for robot = [compact extended]
                testCase.verifyEqual(robot.com,[robot.L1;robot.L2]/2);
                testCase.verifyEqual(robot.inertia, ...
                    [robot.m1*robot.L1^2/12; ...
                    robot.m2*robot.L2^2/12],AbsTol=1e-14);
            end
        end
    end
end
