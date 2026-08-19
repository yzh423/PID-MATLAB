function summary = summarizeStochasticStudy(trialTable)
%SUMMARIZESTOCHASTICSTUDY Aggregate trials with Wilson reliability bounds.
arguments
    trialTable table
end

validateTrialTable(trialTable);
groupKeys = unique(trialTable.Scenario + "|" + ...
    trialTable.Controller,"stable");
groupCount = numel(groupKeys);
Scenario = strings(groupCount,1);
Controller = strings(groupCount,1);
TrialCount = zeros(groupCount,1);
SuccessCount = zeros(groupCount,1);
SuccessRate = zeros(groupCount,1);
SuccessLower95 = zeros(groupCount,1);
SuccessUpper95 = zeros(groupCount,1);
MeanJointRms = zeros(groupCount,1);
StdJointRms = zeros(groupCount,1);
MeanEndEffectorMax = zeros(groupCount,1);
P95EndEffectorMax = zeros(groupCount,1);
MeanTrackingErrorVariance = zeros(groupCount,1);
MeanTorqueSlew = zeros(groupCount,1);
MeanSaturationTime = zeros(groupCount,1);
WorstSaturationTime = zeros(groupCount,1);
WorstFiniteRecoveryTime = NaN(groupCount,1);
NonRecoveryCount = zeros(groupCount,1);
PositionNoiseStdDeg = zeros(groupCount,1);
VelocityNoiseStdDegPerSec = zeros(groupCount,1);

for index = 1:groupCount
    selected = trialTable.Scenario + "|" + ...
        trialTable.Controller == groupKeys(index);
    rows = trialTable(selected,:);
    Scenario(index) = rows.Scenario(1);
    Controller(index) = rows.Controller(1);
    TrialCount(index) = height(rows);
    SuccessCount(index) = nnz(rows.Success);
    SuccessRate(index) = SuccessCount(index)/TrialCount(index);
    [SuccessLower95(index),SuccessUpper95(index)] = ...
        wilsonInterval(SuccessCount(index),TrialCount(index));
    MeanJointRms(index) = mean(rows.JointRmsMean);
    StdJointRms(index) = std(rows.JointRmsMean);
    MeanEndEffectorMax(index) = mean(rows.EndEffectorMax);
    P95EndEffectorMax(index) = nearestRank(rows.EndEffectorMax,0.95);
    MeanTrackingErrorVariance(index) = ...
        mean(rows.TrackingErrorVarianceMean);
    MeanTorqueSlew(index) = mean(rows.TorqueSlewMean);
    MeanSaturationTime(index) = mean(rows.TotalSaturationTime);
    WorstSaturationTime(index) = max(rows.TotalSaturationTime);
    finiteRecovery = rows.RecoveryTime(isfinite(rows.RecoveryTime));
    if ~isempty(finiteRecovery)
        WorstFiniteRecoveryTime(index) = max(finiteRecovery);
    end
    NonRecoveryCount(index) = nnz(isinf(rows.RecoveryTime));
    PositionNoiseStdDeg(index) = mean(rows.PositionNoiseStdDeg);
    VelocityNoiseStdDegPerSec(index) = ...
        mean(rows.VelocityNoiseStdDegPerSec);
end

summary = table(Scenario,Controller,TrialCount,SuccessCount,SuccessRate, ...
    SuccessLower95,SuccessUpper95,MeanJointRms,StdJointRms, ...
    MeanEndEffectorMax,P95EndEffectorMax,MeanTrackingErrorVariance, ...
    MeanTorqueSlew,MeanSaturationTime,WorstSaturationTime, ...
    WorstFiniteRecoveryTime,NonRecoveryCount,PositionNoiseStdDeg, ...
    VelocityNoiseStdDegPerSec);
end

function [lower,upper] = wilsonInterval(successCount,trialCount)
z = 1.95996398454005;
rate = successCount/trialCount;
denominator = 1 + z^2/trialCount;
center = (rate + z^2/(2*trialCount))/denominator;
half = z*sqrt(rate*(1-rate)/trialCount + ...
    z^2/(4*trialCount^2))/denominator;
lower = max(0,center-half);
upper = min(1,center+half);
end

function value = nearestRank(values,probability)
ordered = sort(values);
index = max(1,ceil(probability*numel(ordered)));
value = ordered(index);
end

function validateTrialTable(trialTable)
required = ["Scenario","Controller","Trial","Seed","Success", ...
    "JointRmsMean","EndEffectorMax","TrackingErrorVarianceMean", ...
    "TorqueSlewMean","TotalSaturationTime","RecoveryTime", ...
    "PositionNoiseStdDeg","VelocityNoiseStdDegPerSec"];
if isempty(trialTable) || ...
        ~all(ismember(required,string(trialTable.Properties.VariableNames)))
    invalidTable("Trial table is empty or incomplete.");
end
keys = trialTable.Scenario + "|" + trialTable.Controller + "|" + ...
    string(trialTable.Trial) + "|" + string(trialTable.Seed);
if numel(unique(keys)) ~= height(trialTable)
    invalidTable("Trial combinations must be unique.");
end
finiteNames = ["JointRmsMean","EndEffectorMax", ...
    "TrackingErrorVarianceMean","TorqueSlewMean", ...
    "TotalSaturationTime","PositionNoiseStdDeg", ...
    "VelocityNoiseStdDegPerSec"];
if any(~isfinite(trialTable{:,finiteNames}),"all") || ...
        any(trialTable.Trial < 1) || any(trialTable.Seed < 0)
    invalidTable("Required trial metrics must be finite and valid.");
end
end

function invalidTable(message)
error("rrm:robustness:InvalidStochasticTrialTable","%s",message);
end
