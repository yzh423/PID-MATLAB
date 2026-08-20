classdef TestMakePickAndPlaceTask < matlab.unittest.TestCase
    methods (Test)
        function createsFrozenReachableTask(testCase)
            robot = rrm.config.makeRobot("baseline");

            task = rrm.trajectory.makePickAndPlaceTask(robot,0.01);

            expectedWaypoints = [0.55 0.45 0.45 0.22; ...
                0.12 -0.02 0.32 0.48];
            testCase.verifyEqual(task.name,"pick-transfer-place");
            testCase.verifyEqual(task.waypointNames, ...
                ["start";"pickup";"safe";"place"]);
            testCase.verifyEqual(task.waypoints,expectedWaypoints);
            testCase.verifyEqual(task.moveDurations,[1.4;1.2;1.5]);
            testCase.verifyEqual(task.dwellDurations,[0.4;0;0.8]);
            testCase.verifyEqual(task.pickupEvaluationIndex, ...
                task.path.dwellEndIndices(1));
            testCase.verifyEqual(task.placeEvaluationIndex, ...
                task.path.dwellEndIndices(3));
            testCase.verifyEqual(task.evaluationIndices.pickup, ...
                task.pickupEvaluationIndex);
            testCase.verifyEqual(task.evaluationIndices.place, ...
                task.placeEvaluationIndex);
            testCase.verifyGreaterThan(task.reference.q(2,:),0);
            reconstructionError = zeros(1,numel(task.path.time));
            for sample = 1:numel(task.path.time)
                reconstructionError(sample) = norm( ...
                    rrm.kinematics.forward(robot, ...
                    task.reference.q(:,sample))- ...
                    task.path.position(:,sample));
            end
            testCase.verifyLessThan(max(reconstructionError),1e-10);
        end
    end
end
