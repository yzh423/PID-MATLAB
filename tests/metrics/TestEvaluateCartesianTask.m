classdef TestEvaluateCartesianTask < matlab.unittest.TestCase
    methods (Test)
        function calculatesKnownCartesianAndWaypointMetrics(testCase)
            [robot,result,reference,indices] = fixture();
            expectedActual = forwardHistory(robot,result.q);
            expectedError = vecnorm( ...
                reference.cartesian.position-expectedActual,2,1);

            metrics = rrm.metrics.evaluateCartesianTask( ...
                result,robot,reference,indices);

            testCase.verifyEqual(metrics.actualPosition, ...
                expectedActual,AbsTol=1e-12);
            testCase.verifyEqual(metrics.cartesianError, ...
                expectedError,AbsTol=1e-12);
            testCase.verifyEqual(metrics.cartesianRms, ...
                sqrt(mean(expectedError.^2)),AbsTol=1e-12);
            testCase.verifyEqual(metrics.cartesianMax, ...
                max(expectedError),AbsTol=1e-12);
            testCase.verifyEqual(metrics.pickupError, ...
                expectedError(indices.pickup),AbsTol=1e-12);
            testCase.verifyEqual(metrics.placeError, ...
                expectedError(indices.place),AbsTol=1e-12);
            testCase.verifyEqual(metrics.totalSaturationTime,0);
            testCase.verifyTrue(metrics.taskSuccess);
        end

        function appliesEveryFrozenSuccessCondition(testCase)
            [robot,result,reference,indices] = perfectFixture();
            baseline = rrm.metrics.evaluateCartesianTask( ...
                result,robot,reference,indices);
            testCase.verifyTrue(baseline.taskSuccess);

            highRms = reference;
            highRms.cartesian.position = ...
                highRms.cartesian.position+[0.06;0];
            testCase.verifyFalse(rrm.metrics.evaluateCartesianTask( ...
                result,robot,highRms,indices).taskSuccess);

            highMaximum = reference;
            highMaximum.cartesian.position(:,2) = ...
                highMaximum.cartesian.position(:,2)+[0.16;0];
            testCase.verifyFalse(rrm.metrics.evaluateCartesianTask( ...
                result,robot,highMaximum,struct()).taskSuccess);

            highWaypoint = reference;
            highWaypoint.cartesian.position(:,2) = ...
                highWaypoint.cartesian.position(:,2)+[0.051;0];
            testCase.verifyFalse(rrm.metrics.evaluateCartesianTask( ...
                result,robot,highWaypoint,indices).taskSuccess);

            saturated = result;
            saturated.saturated(1,2) = true;
            testCase.verifyFalse(rrm.metrics.evaluateCartesianTask( ...
                saturated,robot,reference,indices).taskSuccess);

            commonFailure = result;
            commonFailure.qReference(:,2:3) = ...
                commonFailure.qReference(:,2:3)+[0.1;0];
            testCase.verifyFalse(rrm.metrics.evaluateCartesianTask( ...
                commonFailure,robot,reference,indices).taskSuccess);

            failed = result;
            failed.status = "joint-limit-violation";
            testCase.verifyFalse(rrm.metrics.evaluateCartesianTask( ...
                failed,robot,reference,indices).taskSuccess);
        end

        function rejectsInconsistentInput(testCase)
            [robot,result,reference,indices] = perfectFixture();
            reference.cartesian.position = zeros(2,2);
            testCase.verifyError(@() rrm.metrics.evaluateCartesianTask( ...
                result,robot,reference,indices), ...
                "rrm:metrics:InvalidCartesianTaskInput");
            reference.cartesian.position = forwardHistory(robot,result.q);
            indices.pickup = 4;
            testCase.verifyError(@() rrm.metrics.evaluateCartesianTask( ...
                result,robot,reference,indices), ...
                "rrm:metrics:InvalidCartesianTaskInput");
        end
    end
end

function [robot,result,reference,indices] = fixture()
robot = rrm.config.makeRobot("baseline");
qReference = [0 0.2 0.4;0.3 0.2 0.1];
q = qReference+[0 -0.01 -0.01;0 0.01 0.01];
[result,reference,indices] = assemble(robot,q,qReference);
end

function [robot,result,reference,indices] = perfectFixture()
robot = rrm.config.makeRobot("baseline");
q = [0 0.2 0.4;0.3 0.2 0.1];
[result,reference,indices] = assemble(robot,q,q);
end

function [result,reference,indices] = assemble(robot,q,qReference)
time = [0;0.5;1];
position = forwardHistory(robot,qReference);
reference = struct("time",time,"q",qReference, ...
    "dq",zeros(2,3),"ddq",zeros(2,3), ...
    "cartesian",struct("time",time,"position",position, ...
    "velocity",zeros(2,3),"acceleration",zeros(2,3)));
result = struct("time",time,"q",q,"qReference",qReference, ...
    "tau",zeros(2,3),"saturated",false(2,3), ...
    "status","completed");
indices = struct("pickup",2,"place",3);
end

function position = forwardHistory(robot,q)
position = zeros(2,size(q,2));
for sample = 1:size(q,2)
    position(:,sample) = rrm.kinematics.forward(robot,q(:,sample));
end
end
