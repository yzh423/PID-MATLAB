classdef TestRunPidCrossValidation < matlab.unittest.TestCase
    methods (Test)
        function shortRunIsFiniteAndAligned(testCase)
            [robot,controller,reference,options,modelPath] = inputs();

            result = rrm.simulink.runPidCrossValidation( ...
                robot,controller,reference,options,modelPath);

            testCase.verifyEqual(result.time,reference.time,"AbsTol",0);
            testCase.verifySize(result.q,size(reference.q));
            testCase.verifySize(result.dq,size(reference.dq));
            testCase.verifySize(result.tau,size(reference.q));
            testCase.verifySize(result.tauUnsaturated,size(reference.q));
            testCase.verifySize(result.saturated,size(reference.q));
            testCase.verifyTrue(all(isfinite(result.q),"all"));
            testCase.verifyTrue(all(isfinite(result.dq),"all"));
            testCase.verifyTrue(all(isfinite(result.tau),"all"));
            testCase.verifyClass(result.saturated,"logical");
            testCase.verifyEqual(result.qReference,reference.q,"AbsTol",0);
            testCase.verifyEqual(result.dqReference,reference.dq,"AbsTol",0);
            testCase.verifyEqual(result.status,"completed");
            testCase.verifyEqual(result.completedSamples,numel(reference.time));
        end

        function rejectsFuzzyController(testCase)
            [robot,~,reference,options,modelPath] = inputs();
            fuzzy = rrm.config.makeFuzzyPidController(robot);

            testCase.verifyError(@() rrm.simulink.runPidCrossValidation( ...
                robot,fuzzy,reference,options,modelPath), ...
                "rrm:simulink:UnsupportedController");
        end

        function rejectsNonNominalEnvironment(testCase)
            [robot,controller,reference,options,modelPath] = inputs();
            options.disturbanceTorque = [1;0];

            testCase.verifyError(@() rrm.simulink.runPidCrossValidation( ...
                robot,controller,reference,options,modelPath), ...
                "rrm:simulink:UnsupportedEnvironment");
        end

        function shortRunDoesNotLeakToolchainWarning(testCase)
            [robot,controller,reference,options,modelPath] = inputs();

            testCase.verifyWarningFree( ...
                @() rrm.simulink.runPidCrossValidation( ...
                robot,controller,reference,options,modelPath));
        end

        function shortRunMatchesMatlabExecution(testCase)
            [robot,controller,reference,options,modelPath] = inputs();
            matlabRun = rrm.simulation.runController( ...
                robot,controller,reference,options);
            simulinkRun = rrm.simulink.runPidCrossValidation( ...
                robot,controller,reference,options,modelPath);

            comparison = rrm.simulink.comparePidRuns( ...
                matlabRun,simulinkRun);

            testCase.verifyTrue(comparison.pass,comparison.failureSummary);
        end
    end
end

function [robot,controller,reference,options,modelPath] = inputs()
robot = rrm.config.makeRobot("baseline");
controller = rrm.config.makePidController(robot);
reference = rrm.trajectory.quintic( ...
    [0;0],deg2rad([5;8]),0.02,0.001,0.03);
options = rrm.config.makeSimulationOptions();
modelPath = fullfile("models","rrm_pid_cross_validation.slx");
end
