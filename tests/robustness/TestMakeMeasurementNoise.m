classdef TestMakeMeasurementNoise < matlab.unittest.TestCase
    methods (Test)
        function sameSeedIsExactlyReproducible(testCase)
            spec = noiseSpec();
            first = rrm.robustness.makeMeasurementNoise(spec,25,42001);
            second = rrm.robustness.makeMeasurementNoise(spec,25,42001);

            testCase.verifyEqual(first, second);
            testCase.verifySize(first.position, [2 25]);
            testCase.verifySize(first.velocity, [2 25]);
            testCase.verifyEqual(first.seed, 42001);
        end

        function differentSeedsProduceDifferentHistories(testCase)
            spec = noiseSpec();
            first = rrm.robustness.makeMeasurementNoise(spec,25,42001);
            second = rrm.robustness.makeMeasurementNoise(spec,25,42002);
            testCase.verifyNotEqual(first.position, second.position);
            testCase.verifyNotEqual(first.velocity, second.velocity);
        end

        function standardDeviationsScaleIdenticalUnderlyingDraws(testCase)
            spec = noiseSpec();
            doubled = spec;
            doubled.positionStd = 2*spec.positionStd;
            doubled.velocityStd = 2*spec.velocityStd;
            base = rrm.robustness.makeMeasurementNoise(spec,25,42001);
            scaled = rrm.robustness.makeMeasurementNoise(doubled,25,42001);

            testCase.verifyEqual(scaled.position, 2*base.position);
            testCase.verifyEqual(scaled.velocity, 2*base.velocity);

            zeroSpec = struct("positionStd",[0;0],"velocityStd",[0;0]);
            zeroNoise = rrm.robustness.makeMeasurementNoise( ...
                zeroSpec,25,42001);
            testCase.verifyEqual(zeroNoise.position, zeros(2,25));
            testCase.verifyEqual(zeroNoise.velocity, zeros(2,25));
        end

        function globalRandomStateIsUnchanged(testCase)
            rng(173,"twister");
            stateBefore = rng;
            rrm.robustness.makeMeasurementNoise(noiseSpec(),25,42001);
            stateAfter = rng;
            testCase.verifyEqual(stateAfter, stateBefore);
        end

        function invalidSpecificationsAreRejected(testCase)
            valid = noiseSpec();
            invalidSpecs = { ...
                struct("positionStd",[-1;0], ...
                    "velocityStd",valid.velocityStd), ...
                struct("positionStd",valid.positionStd, ...
                    "velocityStd",[NaN;0]), ...
                struct("positionStd",[1 2], ...
                    "velocityStd",valid.velocityStd), ...
                struct("positionStd",valid.positionStd), ...
                "not-a-struct"};
            for value = invalidSpecs
                testCase.verifyError(@() ...
                    rrm.robustness.makeMeasurementNoise( ...
                    value{1},25,42001), ...
                    "rrm:robustness:InvalidNoiseSpecification");
            end
            testCase.verifyError(@() ...
                rrm.robustness.makeMeasurementNoise(valid,0,42001), ...
                "rrm:robustness:InvalidNoiseSpecification");
            testCase.verifyError(@() ...
                rrm.robustness.makeMeasurementNoise(valid,2.5,42001), ...
                "rrm:robustness:InvalidNoiseSpecification");
        end

        function invalidSeedsAreRejected(testCase)
            spec = noiseSpec();
            for seed = [-1,1.5,Inf]
                testCase.verifyError(@() ...
                    rrm.robustness.makeMeasurementNoise(spec,25,seed), ...
                    "rrm:robustness:InvalidSeed");
            end
        end
    end
end

function spec = noiseSpec()
spec = struct( ...
    "positionStd", deg2rad([0.2;0.4]), ...
    "velocityStd", deg2rad([2;4]));
end
