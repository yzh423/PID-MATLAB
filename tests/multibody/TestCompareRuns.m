classdef TestCompareRuns < matlab.unittest.TestCase
    methods (Test)
        function exactCopiesPass(testCase)
            robot = rrm.config.makeRobot("baseline");
            [matlabRun,multibodyRun] = syntheticRuns(robot);

            comparison = rrm.multibody.compareRuns( ...
                matlabRun,multibodyRun,robot);

            testCase.verifyTrue(comparison.pass);
            testCase.verifyEqual(comparison.qRmsDifference,zeros(2,1));
            testCase.verifyEqual(comparison.endEffectorRmsDifference,0);
            testCase.verifyEqual(comparison.failureSummary,"");
        end

        function endEffectorSpikeFailsFrozenLimit(testCase)
            robot = rrm.config.makeRobot("baseline");
            [matlabRun,multibodyRun] = syntheticRuns(robot);
            multibodyRun.endEffectorPosition(1,3) = ...
                multibodyRun.endEffectorPosition(1,3) + 6e-3;

            comparison = rrm.multibody.compareRuns( ...
                matlabRun,multibodyRun,robot);

            testCase.verifyFalse(comparison.flags.endEffectorMax);
            testCase.verifyFalse(comparison.pass);
            testCase.verifyTrue(contains(comparison.failureSummary,"ee-max"));
        end

        function angleSpikeFailsFrozenLimits(testCase)
            robot = rrm.config.makeRobot("baseline");
            [matlabRun,multibodyRun] = syntheticRuns(robot);
            multibodyRun.q(1,3) = multibodyRun.q(1,3) + 6e-3;

            comparison = rrm.multibody.compareRuns( ...
                matlabRun,multibodyRun,robot);

            testCase.verifyFalse(comparison.flags.qRms(1));
            testCase.verifyFalse(comparison.flags.qMax(1));
            testCase.verifyTrue(contains(comparison.failureSummary,"q-rms-j1"));
            testCase.verifyTrue(contains(comparison.failureSummary,"q-max-j1"));
        end

        function outOfPlaneMotionFails(testCase)
            robot = rrm.config.makeRobot("baseline");
            [matlabRun,multibodyRun] = syntheticRuns(robot);
            multibodyRun.endEffectorPosition(3,4) = 2e-9;

            comparison = rrm.multibody.compareRuns( ...
                matlabRun,multibodyRun,robot);

            testCase.verifyFalse(comparison.flags.planar);
            testCase.verifyTrue(contains(comparison.failureSummary,"planar"));
        end

        function excessiveSaturationDifferenceFails(testCase)
            robot = rrm.config.makeRobot("baseline");
            [matlabRun,multibodyRun] = syntheticRuns(robot);
            multibodyRun.saturated(2,1:7) = true;

            comparison = rrm.multibody.compareRuns( ...
                matlabRun,multibodyRun,robot);

            testCase.verifyFalse(comparison.flags.saturationTime(2));
            testCase.verifyTrue(contains( ...
                comparison.failureSummary,"saturation-j2"));
        end

        function shiftedTimeRaisesStableError(testCase)
            robot = rrm.config.makeRobot("baseline");
            [matlabRun,multibodyRun] = syntheticRuns(robot);
            multibodyRun.time = multibodyRun.time + 0.001;

            testCase.verifyError(@() rrm.multibody.compareRuns( ...
                matlabRun,multibodyRun,robot), ...
                "rrm:multibody:TimeGridMismatch");
        end

        function nonfiniteHistoryRaisesStableError(testCase)
            robot = rrm.config.makeRobot("baseline");
            [matlabRun,multibodyRun] = syntheticRuns(robot);
            multibodyRun.endEffectorPosition(1,2) = NaN;

            testCase.verifyError(@() rrm.multibody.compareRuns( ...
                matlabRun,multibodyRun,robot), ...
                "rrm:multibody:NonFiniteComparisonData");
        end
    end
end

function [matlabRun,multibodyRun] = syntheticRuns(robot)
time = (0:0.001:0.010).';
q = zeros(2,numel(time));
endEffectorPosition = zeros(3,numel(time));
for sample = 1:numel(time)
    endEffectorPosition(1:2,sample) = ...
        rrm.kinematics.forward(robot,q(:,sample));
end
matlabRun = struct( ...
    "time",time, ...
    "q",q, ...
    "dq",zeros(2,numel(time)), ...
    "tau",zeros(2,numel(time)), ...
    "saturated",false(2,numel(time)), ...
    "status","completed", ...
    "completedSamples",numel(time));
multibodyRun = matlabRun;
multibodyRun.endEffectorPosition = endEffectorPosition;
end
