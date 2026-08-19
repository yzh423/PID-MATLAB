classdef TestMakeDeterministicScenarios < matlab.unittest.TestCase
    methods (Test)
        function fullModeHasExactOrderedScenarios(testCase)
            [reference, options] = fixtures();
            scenarios = rrm.robustness.makeDeterministicScenarios( ...
                reference, options, "full");

            expected = ["nominal","payload-0.0kg","payload-1.0kg", ...
                "payload-1.5kg","configuration-compact", ...
                "configuration-extended","mass-inertia-minus-20pct", ...
                "mass-inertia-minus-10pct","mass-inertia-plus-10pct", ...
                "mass-inertia-plus-20pct","disturbance-pulse", ...
                "actuator-derated","combined-deterministic"];
            testCase.verifyEqual([scenarios.name], expected);
            testCase.verifyEqual(numel(unique([scenarios.name])), 13);
            required = ["name","category","robot","options", ...
                "disturbanceWindow","payload","lengthScale", ...
                "uncertaintyScale","torqueScale"];
            testCase.verifyTrue(all(isfield(scenarios, required)));
        end

        function mutationsMatchSpecification(testCase)
            [reference, options] = fixtures();
            scenarios = rrm.robustness.makeDeterministicScenarios( ...
                reference, options, "full");
            byName = @(name) scenarios([scenarios.name] == name);

            testCase.verifyEqual(byName("payload-0.0kg").robot.payload, 0);
            testCase.verifyEqual(byName("payload-1.0kg").robot.payload, 1);
            testCase.verifyEqual(byName("payload-1.5kg").robot.payload, 1.5);
            compact = byName("configuration-compact").robot;
            extended = byName("configuration-extended").robot;
            testCase.verifyEqual([compact.L1 compact.L2], [0.35 0.25]);
            testCase.verifyEqual([extended.L1 extended.L2], [0.55 0.45]);

            baseline = rrm.config.makeRobot("baseline");
            minus = byName("mass-inertia-minus-20pct").robot;
            plus = byName("mass-inertia-plus-20pct").robot;
            testCase.verifyEqual([minus.m1;minus.m2;minus.inertia], ...
                0.8*[baseline.m1;baseline.m2;baseline.inertia]);
            testCase.verifyEqual([plus.m1;plus.m2;plus.inertia], ...
                1.2*[baseline.m1;baseline.m2;baseline.inertia]);
            testCase.verifyEqual(minus.payload, baseline.payload);
        end

        function pulseAndCombinedCaseAreExact(testCase)
            [reference, options] = fixtures();
            scenarios = rrm.robustness.makeDeterministicScenarios( ...
                reference, options, "full");
            byName = @(name) scenarios([scenarios.name] == name);
            active = reference.time >= 2.00 & reference.time <= 2.10;
            disturbance = byName("disturbance-pulse");
            testCase.verifyEqual( ...
                disturbance.options.disturbanceTorque(:,active), ...
                repmat([4;-3], 1, nnz(active)));
            testCase.verifyEqual( ...
                disturbance.options.disturbanceTorque(:,~active), ...
                zeros(2, nnz(~active)));
            testCase.verifyEqual(disturbance.disturbanceWindow, [2;2.1]);

            combined = byName("combined-deterministic");
            testCase.verifyEqual(combined.robot.torqueLimits, [18;10]);
            testCase.verifyEqual(combined.robot.payload, 1.0);
            testCase.verifyEqual([combined.robot.L1 combined.robot.L2], ...
                [0.55 0.45]);
            unscaled = rrm.config.makeRobot("extended");
            testCase.verifyEqual([combined.robot.m1;combined.robot.m2; ...
                combined.robot.inertia], ...
                1.2*[unscaled.m1;unscaled.m2;unscaled.inertia]);
            testCase.verifyEqual( ...
                combined.options.disturbanceTorque(:,active), ...
                repmat([4;-3], 1, nnz(active)));
        end

        function smokeModeKeepsFourRepresentativeCases(testCase)
            [reference, options] = fixtures();
            scenarios = rrm.robustness.makeDeterministicScenarios( ...
                reference, options, "smoke");
            testCase.verifyEqual([scenarios.name], ...
                ["nominal","disturbance-pulse","actuator-derated", ...
                "combined-deterministic"]);
        end
    end
end

function [reference, options] = fixtures()
options = rrm.config.makeSimulationOptions();
reference = rrm.trajectory.quintic( ...
    [0;0], deg2rad([45;60]), 3, options.sampleTime, 5);
end
