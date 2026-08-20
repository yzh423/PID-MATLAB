classdef TestRigidBodyValidation < matlab.unittest.TestCase
    methods (Test)
        function treeMatchesTopology(testCase)
            robot = rrm.config.makeRobot("baseline");

            tree = rrm.validation.makeRigidBodyTree(robot);

            testCase.verifyEqual(tree.NumBodies, 3);
            testCase.verifyEqual(string(tree.DataFormat), "column");
            testCase.verifyEqual(tree.Gravity, [0 -robot.gravity 0], ...
                "AbsTol", 0);
            testCase.verifyEqual(string(tree.BodyNames), ...
                ["link1" "link2" "payload"]);
        end

        function dynamicsAgreeOnGrid(testCase)
            robot = rrm.config.makeRobot("baseline");

            report = rrm.validation.compareRigidBodyDynamics(robot);

            testCase.verifyGreaterThan(report.sampleCount, 100);
            testCase.verifyLessThanOrEqual( ...
                report.maxMassMatrixError, 1e-10);
            testCase.verifyLessThanOrEqual( ...
                report.maxVelocityProductError, 1e-10);
            testCase.verifyLessThanOrEqual( ...
                report.maxGravityError, 1e-10);
        end

        function acceptsExplicitStateGrid(testCase)
            robot = rrm.config.makeRobot("baseline");
            states = struct( ...
                "q", deg2rad([0 45 -30; 0 -20 60]), ...
                "dq", [0 1 -0.5; 0 -0.25 0.75]);

            report = rrm.validation.compareRigidBodyDynamics(robot, states);

            testCase.verifyEqual(report.sampleCount, 3);
            testCase.verifySize(report.massMatrixError, [2 2 3]);
            testCase.verifySize(report.velocityProductError, [2 3]);
            testCase.verifySize(report.gravityError, [2 3]);
        end

        function rejectsMalformedStateGrid(testCase)
            robot = rrm.config.makeRobot("baseline");
            bad = struct("q",zeros(3,1),"dq",zeros(2,1));

            testCase.verifyError( ...
                @() rrm.validation.compareRigidBodyDynamics(robot,bad), ...
                "rrm:validation:InvalidStateGrid");
        end
    end
end
