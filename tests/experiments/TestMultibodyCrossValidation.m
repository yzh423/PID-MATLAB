classdef TestMultibodyCrossValidation < matlab.unittest.TestCase
    methods (Test)
        function smokeModeCreatesCompleteEvidence(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            outputRoot = tempname;
            mkdir(outputRoot);
            testCase.addTeardown(@() rmdir(outputRoot,"s"));
            multibodyValidationMode = "smoke"; %#ok<NASGU>

            run(fullfile(projectRoot,"experiments", ...
                "run_multibody_cross_validation.m"));

            dataDirectory = fullfile(outputRoot,"data");
            for fileName = ["multibody_cross_validation.mat", ...
                    "multibody_cross_validation_runs.csv"]
                file = dir(fullfile(dataDirectory,fileName));
                testCase.verifyEqual(numel(file),1);
                testCase.verifyGreaterThan(file.bytes,0);
            end
            saved = load(fullfile(dataDirectory, ...
                "multibody_cross_validation.mat"));
            testCase.verifyEqual(height(saved.runTable),2);
            testCase.verifyEqual(numel(saved.runs),2);
            testCase.verifyEqual(saved.runTable.Controller, ...
                ["manual-pid";"optimization-pid"]);
            testCase.verifyTrue(all(saved.runTable.MatlabStatus == "completed"));
            testCase.verifyTrue(all(saved.runTable.MultibodyStatus == "completed"));
            testCase.verifyTrue(all(saved.runTable.AgreementPass));
            testCase.verifyTrue(all(isfinite( ...
                saved.runTable{:,vartype("numeric")}),"all"));
            for suffix = ["tracking","path","torque","summary","model"]
                file = dir(fullfile(outputRoot,"figures", ...
                    "multibody_cross_validation_"+suffix+".png"));
                testCase.verifyEqual(numel(file),1);
                testCase.verifyGreaterThan(file.bytes,0);
            end
            testCase.verifyFalse(isfolder(fullfile(outputRoot,"videos")));
        end

        function ignoresStaleCallerControllerDefinitions(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            outputRoot = tempname;
            mkdir(outputRoot);
            testCase.addTeardown(@() rmdir(outputRoot,"s"));
            multibodyValidationMode = "smoke"; %#ok<NASGU>
            staleController = struct( ...
                "name","stale-controller", ...
                "controller",rrm.config.makePidController( ...
                rrm.config.makeRobot("baseline")));
            controllerDefinitions = repmat(staleController,3,1); %#ok<NASGU>

            run(fullfile(projectRoot,"experiments", ...
                "run_multibody_cross_validation.m"));

            saved = load(fullfile(outputRoot,"data", ...
                "multibody_cross_validation.mat"));
            testCase.verifyEqual(saved.runTable.Controller, ...
                ["manual-pid";"optimization-pid"]);
        end
    end
end
