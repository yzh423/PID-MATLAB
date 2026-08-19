classdef TestMakeOptimizedPidController < matlab.unittest.TestCase
    methods (Test)
        function reproducesVerifiedPhaseThreeController(testCase)
            robot = rrm.config.makeRobot("baseline");
            controller = rrm.config.makeOptimizedPidController(robot);

            testCase.verifyEqual(controller.name,"optimization-pid");
            testCase.verifyEqual(controller.type,"pid");
            testCase.verifyEqual(controller.Kp,[240;200]);
            testCase.verifyEqual(controller.Ki,[79.9554;30.2026]);
            testCase.verifyEqual(controller.Kd,[29.3133;18.3972]);
            testCase.verifyEqual(controller.torqueLimits,robot.torqueLimits);
            testCase.verifyEqual(controller.source,"phase-3-fmincon");
        end
    end
end
