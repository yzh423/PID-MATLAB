classdef TestRunCrossValidation < matlab.unittest.TestCase
    methods (Test)
        function shortRunIsFiniteAndAligned(testCase)
            [robot,controller,reference,options,modelPath] = inputs();
            before = evalin("base","who");

            result = rrm.multibody.runCrossValidation( ...
                robot,controller,reference,options,modelPath);

            testCase.verifyEqual(result.time,reference.time,"AbsTol",0);
            testCase.verifySize(result.q,size(reference.q));
            testCase.verifySize(result.dq,size(reference.dq));
            testCase.verifySize(result.tau,size(reference.q));
            testCase.verifySize(result.tauUnsaturated,size(reference.q));
            testCase.verifySize(result.saturated,size(reference.q));
            testCase.verifySize(result.endEffectorPosition, ...
                [3 numel(reference.time)]);
            testCase.verifyTrue(all(isfinite([result.q;result.dq; ...
                result.tau;result.tauUnsaturated; ...
                result.endEffectorPosition]),"all"));
            testCase.verifyClass(result.saturated,"logical");
            testCase.verifyEqual(result.qReference,reference.q,"AbsTol",0);
            testCase.verifyEqual(result.dqReference,reference.dq,"AbsTol",0);
            testCase.verifyEqual(result.status,"completed");
            testCase.verifyEqual(result.completedSamples,numel(reference.time));
            testCase.verifyEqual(result.modelName, ...
                "rrm_multibody_cross_validation");
            testCase.verifyEqual(evalin("base","who"),before);
        end

        function rejectsFuzzyController(testCase)
            [robot,~,reference,options,modelPath] = inputs();
            fuzzy = rrm.config.makeFuzzyPidController(robot);

            testCase.verifyError(@() rrm.multibody.runCrossValidation( ...
                robot,fuzzy,reference,options,modelPath), ...
                "rrm:multibody:UnsupportedController");
        end

        function rejectsDisturbanceEnvironment(testCase)
            [robot,controller,reference,options,modelPath] = inputs();
            options.disturbanceTorque = [1;0];

            testCase.verifyError(@() rrm.multibody.runCrossValidation( ...
                robot,controller,reference,options,modelPath), ...
                "rrm:multibody:UnsupportedEnvironment");
        end

        function shortRunDoesNotLeakWarnings(testCase)
            [robot,controller,reference,options,modelPath] = inputs();

            testCase.verifyWarningFree( ...
                @() rrm.multibody.runCrossValidation( ...
                robot,controller,reference,options,modelPath));
        end
    end
end

function [robot,controller,reference,options,modelPath] = inputs()
robot = rrm.config.makeRobot("baseline");
controller = rrm.config.makePidController(robot);
reference = rrm.trajectory.quintic( ...
    [0;0],deg2rad([5;8]),0.02,0.001,0.03);
options = rrm.config.makeSimulationOptions();
modelPath = fullfile("models","rrm_multibody_cross_validation.slx");
end
