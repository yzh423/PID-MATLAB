classdef TestDifferentialKinematics < matlab.unittest.TestCase
    methods (Test)
        function jacobianMatchesForwardDifference(testCase)
            robot = rrm.config.makeRobot("baseline");
            q = deg2rad([28;-47]);
            h = 1e-6;
            numerical = zeros(2,2);
            for joint = 1:2
                step = zeros(2,1);
                step(joint) = h;
                numerical(:,joint) = ( ...
                    rrm.kinematics.forward(robot,q+step)- ...
                    rrm.kinematics.forward(robot,q-step))/(2*h);
            end

            actual = rrm.kinematics.jacobian(robot,q);

            testCase.verifyEqual(actual,numerical,AbsTol=1e-9);
        end

        function jacobianDotMatchesDirectionalDifference(testCase)
            robot = rrm.config.makeRobot("baseline");
            q = deg2rad([28;-47]);
            dq = [0.4;-0.2];
            h = 1e-6;
            numerical = (rrm.kinematics.jacobian(robot,q+h*dq)- ...
                rrm.kinematics.jacobian(robot,q-h*dq))/(2*h);

            actual = rrm.kinematics.jacobianDot(robot,q,dq);

            testCase.verifyEqual(actual,numerical,AbsTol=1e-9);
        end
    end
end
