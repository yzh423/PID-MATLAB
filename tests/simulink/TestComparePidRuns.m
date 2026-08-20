classdef TestComparePidRuns < matlab.unittest.TestCase
    methods (Test)
        function exactCopiesPass(testCase)
            matlabRun = syntheticRun();
            simulinkRun = matlabRun;

            comparison = rrm.simulink.comparePidRuns(matlabRun,simulinkRun);

            testCase.verifyTrue(comparison.pass);
            testCase.verifyEqual(comparison.qRmsDifference,zeros(2,1));
            testCase.verifyEqual(comparison.qMaxDifference,zeros(2,1));
            testCase.verifyEqual(comparison.saturationTimeDifference,zeros(2,1));
            testCase.verifyEqual(comparison.failureSummary,"");
        end

        function angleSpikeFailsFrozenLimits(testCase)
            matlabRun = syntheticRun();
            simulinkRun = matlabRun;
            simulinkRun.q(1,3) = 6e-5;

            comparison = rrm.simulink.comparePidRuns(matlabRun,simulinkRun);

            testCase.verifyFalse(comparison.pass);
            testCase.verifyFalse(comparison.flags.qRms(1));
            testCase.verifyFalse(comparison.flags.qMax(1));
            testCase.verifyTrue(contains(comparison.failureSummary,"q-rms-j1"));
            testCase.verifyTrue(contains(comparison.failureSummary,"q-max-j1"));
        end

        function oneSampleSaturationDifferencePasses(testCase)
            matlabRun = syntheticRun();
            simulinkRun = matlabRun;
            simulinkRun.saturated(2,3) = true;

            comparison = rrm.simulink.comparePidRuns(matlabRun,simulinkRun);

            testCase.verifyEqual(comparison.saturationTimeDifference(2),0.001, ...
                "AbsTol",10*eps);
            testCase.verifyTrue(comparison.flags.saturationTime(2));
            testCase.verifyTrue(comparison.pass);
        end

        function shiftedTimeRaisesStableError(testCase)
            matlabRun = syntheticRun();
            simulinkRun = matlabRun;
            simulinkRun.time = simulinkRun.time + 0.001;

            testCase.verifyError( ...
                @() rrm.simulink.comparePidRuns(matlabRun,simulinkRun), ...
                "rrm:simulink:TimeGridMismatch");
        end

        function nonfiniteHistoryRaisesStableError(testCase)
            matlabRun = syntheticRun();
            simulinkRun = matlabRun;
            simulinkRun.tau(1,2) = NaN;

            testCase.verifyError( ...
                @() rrm.simulink.comparePidRuns(matlabRun,simulinkRun), ...
                "rrm:simulink:NonFiniteComparisonData");
        end

        function incompleteStatusFails(testCase)
            matlabRun = syntheticRun();
            simulinkRun = matlabRun;
            simulinkRun.status = "joint-limit-violation";

            comparison = rrm.simulink.comparePidRuns(matlabRun,simulinkRun);

            testCase.verifyFalse(comparison.flags.completed);
            testCase.verifyFalse(comparison.pass);
            testCase.verifyTrue(contains(comparison.failureSummary,"completed"));
        end
    end
end

function run = syntheticRun()
time = (0:0.001:0.004).';
run = struct( ...
    "time",time, ...
    "q",zeros(2,numel(time)), ...
    "dq",zeros(2,numel(time)), ...
    "tau",zeros(2,numel(time)), ...
    "saturated",false(2,numel(time)), ...
    "status","completed", ...
    "completedSamples",numel(time));
end
