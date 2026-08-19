classdef TestMakeFuzzyPidController < matlab.unittest.TestCase
    methods (Test)
        function factoryDefinesCompleteBoundedController(testCase)
            robot = rrm.config.makeRobot("baseline");
            controller = rrm.config.makeFuzzyPidController(robot);

            testCase.verifyEqual(controller.type, "fuzzy-pid");
            testCase.verifyEqual(controller.Kp, [120;100]);
            testCase.verifyGreaterThan(controller.errorScale, 0);
            testCase.verifyGreaterThan(controller.errorRateScale, 0);
            testCase.verifyEqual(numel(controller.outputUniverse), 101);
            testCase.verifyGreaterThan(diff(controller.outputUniverse), 0);
            testCase.verifySize(controller.outputMembership, [5 101]);

            gainNames = ["Kp","Ki","Kd"];
            for gainName = gainNames
                testCase.verifySize(controller.rules.(gainName), [5 5]);
                testCase.verifyGreaterThanOrEqual( ...
                    controller.rules.(gainName), 1);
                testCase.verifyLessThanOrEqual( ...
                    controller.rules.(gainName), 5);
                testCase.verifyGreaterThan( ...
                    controller.gainBounds.upper.(gainName), ...
                    controller.gainBounds.lower.(gainName));
            end
        end

        function gainBoundsMatchRelativeCorrectionRanges(testCase)
            robot = rrm.config.makeRobot("baseline");
            controller = rrm.config.makeFuzzyPidController(robot);
            gainNames = ["Kp","Ki","Kd"];

            for gainName = gainNames
                baseGain = controller.(gainName);
                fraction = controller.correctionFraction.(gainName);
                testCase.verifyEqual( ...
                    controller.gainBounds.lower.(gainName), ...
                    baseGain.*(1-fraction), AbsTol=1e-14);
                testCase.verifyEqual( ...
                    controller.gainBounds.upper.(gainName), ...
                    baseGain.*(1+fraction), AbsTol=1e-14);
            end
        end
    end
end
