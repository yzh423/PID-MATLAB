classdef TestMamdani < matlab.unittest.TestCase
    methods (Test)
        function outputsAreFiniteAndBounded(testCase)
            controller = makeController();
            for errorValue = linspace(-1, 1, 7)
                for rateValue = linspace(-1, 1, 7)
                    correction = rrm.fuzzy.mamdani( ...
                        controller, errorValue, rateValue);
                    testCase.verifySize(correction, [3 1]);
                    testCase.verifyTrue(all(isfinite(correction)));
                    testCase.verifyLessThanOrEqual(abs(correction), 1+1e-14);
                end
            end
        end

        function symmetricRulesGiveMirroredInputEquality(testCase)
            controller = makeController();
            positive = rrm.fuzzy.mamdani(controller, 0.7, -0.35);
            negative = rrm.fuzzy.mamdani(controller, -0.7, 0.35);
            testCase.verifyEqual(positive, negative, AbsTol=1e-14);
        end

        function rulesExpressDocumentedGainIntent(testCase)
            controller = makeController();
            largeError = rrm.fuzzy.mamdani(controller, 1, 0);
            stationaryError = rrm.fuzzy.mamdani(controller, 0, 0);

            testCase.verifyGreaterThan(largeError(1), 0);
            testCase.verifyLessThan(largeError(2), 0);
            testCase.verifyGreaterThan(stationaryError(2), 0);
            testCase.verifyEqual(stationaryError(3), 0, AbsTol=1e-14);
        end

        function malformedRuleTableIsRejected(testCase)
            controller = makeController();
            controller.rules.Kp = ones(4,5);
            testCase.verifyError( ...
                @() rrm.fuzzy.mamdani(controller, 0, 0), ...
                "rrm:fuzzy:InvalidConfiguration");
        end
    end
end

function controller = makeController()
controller = rrm.config.makeFuzzyPidController( ...
    rrm.config.makeRobot("baseline"));
end
