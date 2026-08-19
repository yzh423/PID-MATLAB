classdef TestEvaluateRun < matlab.unittest.TestCase
    methods (Test)
        function cartesianMetricsMatchKnownPoses(testCase)
            robot = rrm.config.makeRobot("baseline");
            robot.L1 = 1;
            robot.L2 = 1;
            result = syntheticResult([0 pi/2; 0 0], zeros(2,2), [0;0.1]);
            scenario = noPulseScenario();

            metrics = rrm.robustness.evaluateRun( ...
                result, robot, generousCriteria(), scenario);

            testCase.verifyEqual(metrics.endEffectorRmsError, 2, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(metrics.endEffectorMaxError, 2*sqrt(2), ...
                "AbsTol", 1e-12);
            testCase.verifyTrue(isnan(metrics.recoveryTime));
            testCase.verifyFalse(metrics.success);
        end

        function recoveryRequiresContinuousDwell(testCase)
            time = (0:0.01:0.25).';
            q = zeros(2,numel(time));
            q(:,time < 0.14) = 0.02;
            result = syntheticResult(q, zeros(size(q)), time);
            scenario = noPulseScenario();
            scenario.disturbanceWindow = [0.05;0.10];
            scenario.recoveryBand = 0.01;
            scenario.recoveryDwell = 0.03;

            metrics = rrm.robustness.evaluateRun( ...
                result, rrm.config.makeRobot("baseline"), ...
                generousCriteria(), scenario);

            testCase.verifyEqual(metrics.recoveryTime, 0.04, ...
                "AbsTol", 1e-12);
        end

        function unrecoveredPulseReturnsInfinity(testCase)
            time = (0:0.01:0.25).';
            result = syntheticResult(0.02*ones(2,numel(time)), ...
                zeros(2,numel(time)), time);
            scenario = noPulseScenario();
            scenario.disturbanceWindow = [0.05;0.10];
            scenario.recoveryBand = 0.01;
            scenario.recoveryDwell = 0.03;

            metrics = rrm.robustness.evaluateRun( ...
                result, rrm.config.makeRobot("baseline"), ...
                generousCriteria(), scenario);

            testCase.verifyEqual(metrics.recoveryTime, Inf);
        end

        function saturationTimeSumsBothJoints(testCase)
            time = (0:0.1:0.3).';
            result = syntheticResult(zeros(2,4), zeros(2,4), time);
            result.saturated = logical([1 1 1 1; 0 1 1 0]);
            metrics = rrm.robustness.evaluateRun( ...
                result, rrm.config.makeRobot("baseline"), ...
                generousCriteria(), noPulseScenario());
            expected = sum(trapz(time, double(result.saturated), 2));
            testCase.verifyEqual(metrics.totalSaturationTime, expected, ...
                "AbsTol", 1e-12);
        end
    end
end

function result = syntheticResult(q, qReference, time)
sampleCount = numel(time);
result = struct( ...
    "time", time, ...
    "q", q, ...
    "qReference", qReference, ...
    "tau", zeros(2,sampleCount), ...
    "saturated", false(2,sampleCount), ...
    "status", "completed");
end

function criteria = generousCriteria()
criteria = struct( ...
    "steadyStateWindow", 0.05, ...
    "steadyStateRmsError", [10;10], ...
    "steadyStateMaxAbsError", [10;10]);
end

function scenario = noPulseScenario()
scenario = struct( ...
    "disturbanceWindow", [NaN;NaN], ...
    "recoveryBand", deg2rad(2), ...
    "recoveryDwell", 0.10);
end
