classdef TestSummarizeStochasticStudy < matlab.unittest.TestCase
    methods (Test)
        function aggregatesInStableControllerOrder(testCase)
            trialTable = makeTable(4);
            trialTable.Controller = ["A";"A";"B";"B"];
            trialTable.Trial = [1;2;1;2];
            trialTable.Seed = [11;12;11;12];
            trialTable.Success = logical([1;0;1;1]);
            trialTable.JointRmsMean = [0.1;0.3;0.2;0.4];
            trialTable.TotalSaturationTime = [0;0.2;0;0.1];
            trialTable.RecoveryTime = [NaN;NaN;0.2;Inf];

            summary = rrm.robustness.summarizeStochasticStudy(trialTable);

            testCase.verifyEqual(summary.Controller,["A";"B"]);
            testCase.verifyEqual(summary.SuccessRate,[0.5;1]);
            testCase.verifyEqual(summary.MeanJointRms,[0.2;0.3], ...
                "AbsTol",1e-12);
            testCase.verifyEqual(summary.WorstSaturationTime,[0.2;0.1], ...
                "AbsTol",1e-12);
            testCase.verifyEqual(summary.NonRecoveryCount,[0;1]);
            testCase.verifyTrue(isnan(summary.WorstFiniteRecoveryTime(1)));
            testCase.verifyEqual(summary.WorstFiniteRecoveryTime(2),0.2);
        end

        function wilsonIntervalMatchesClosedForm(testCase)
            trialTable = makeTable(10);
            trialTable.Success = logical([ones(5,1);zeros(5,1)]);
            summary = rrm.robustness.summarizeStochasticStudy(trialTable);
            z = 1.95996398454005;
            center = (0.5+z^2/(2*10))/(1+z^2/10);
            half = z*sqrt(0.5*0.5/10+z^2/(4*10^2))/(1+z^2/10);
            testCase.verifyEqual(summary.SuccessLower95,center-half, ...
                "AbsTol",1e-12);
            testCase.verifyEqual(summary.SuccessUpper95,center+half, ...
                "AbsTol",1e-12);
        end

        function percentileUsesDocumentedNearestRank(testCase)
            trialTable = makeTable(20);
            trialTable.EndEffectorMax = (1:20).';
            summary = rrm.robustness.summarizeStochasticStudy(trialTable);
            testCase.verifyEqual(summary.P95EndEffectorMax,19);
        end

        function invalidOrDuplicateTrialsAreRejected(testCase)
            trialTable = makeTable(2);
            duplicate = trialTable;
            duplicate.Trial(2) = duplicate.Trial(1);
            duplicate.Seed(2) = duplicate.Seed(1);
            testCase.verifyError(@() ...
                rrm.robustness.summarizeStochasticStudy(duplicate), ...
                "rrm:robustness:InvalidStochasticTrialTable");
            missing = removevars(trialTable,"TorqueSlewMean");
            testCase.verifyError(@() ...
                rrm.robustness.summarizeStochasticStudy(missing), ...
                "rrm:robustness:InvalidStochasticTrialTable");
        end
    end
end

function trialTable = makeTable(count)
Scenario = repmat("scenario",count,1);
Controller = repmat("A",count,1);
Trial = (1:count).';
Seed = (1001:1000+count).';
Success = true(count,1);
JointRmsMean = linspace(0.1,0.2,count).';
EndEffectorMax = linspace(0.02,0.04,count).';
TrackingErrorVarianceMean = linspace(1e-4,2e-4,count).';
TorqueSlewMean = linspace(10,20,count).';
TotalSaturationTime = linspace(0,0.1,count).';
RecoveryTime = NaN(count,1);
PositionNoiseStdDeg = 0.2*ones(count,1);
VelocityNoiseStdDegPerSec = 2*ones(count,1);
trialTable = table(Scenario,Controller,Trial,Seed,Success, ...
    JointRmsMean,EndEffectorMax,TrackingErrorVarianceMean, ...
    TorqueSlewMean,TotalSaturationTime,RecoveryTime, ...
    PositionNoiseStdDeg,VelocityNoiseStdDegPerSec);
end
