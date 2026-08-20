classdef TestSimulinkCrossValidation < matlab.unittest.TestCase
    methods (Test)
        function smokeModeCreatesCompleteEvidence(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            outputRoot = tempname;
            mkdir(outputRoot);
            testCase.addTeardown(@() rmdir(outputRoot,"s"));
            simulinkValidationMode = "smoke";

            run(fullfile(projectRoot,"experiments", ...
                "run_simulink_cross_validation.m"));

            dataDirectory = fullfile(outputRoot,"data");
            figureDirectory = fullfile(outputRoot,"figures");
            dataFiles = ["simulink_cross_validation.mat", ...
                "simulink_cross_validation_runs.csv"];
            for fileName = dataFiles
                file = dir(fullfile(dataDirectory,fileName));
                testCase.verifyEqual(numel(file),1);
                testCase.verifyGreaterThan(file.bytes,0);
            end
            figureNames = ["tracking","differences","torque","summary"];
            for figureName = figureNames
                file = dir(fullfile(figureDirectory, ...
                    "simulink_cross_validation_"+figureName+".png"));
                testCase.verifyEqual(numel(file),1);
                testCase.verifyGreaterThan(file.bytes,0);
            end

            saved = load(fullfile(dataDirectory, ...
                "simulink_cross_validation.mat"));
            testCase.verifyEqual(height(saved.runTable),2);
            testCase.verifyEqual(numel(saved.runs),2);
            testCase.verifyEqual(saved.runTable.Controller, ...
                ["manual-pid";"optimization-pid"]);
            testCase.verifyTrue(all(saved.runTable.MatlabStatus == "completed"));
            testCase.verifyTrue(all(saved.runTable.SimulinkStatus == "completed"));
            testCase.verifyTrue(all(saved.runTable.AgreementPass));
            numericData = saved.runTable{:,vartype("numeric")};
            testCase.verifyTrue(all(isfinite(numericData),"all"));
            testCase.verifyLessThanOrEqual( ...
                saved.dynamicsReport.maxMassMatrixError,1e-10);
            testCase.verifyLessThanOrEqual( ...
                saved.dynamicsReport.maxVelocityProductError,1e-10);
            testCase.verifyLessThanOrEqual( ...
                saved.dynamicsReport.maxGravityError,1e-10);

            for index = 1:2
                testCase.verifyEqual( ...
                    saved.runs(index).matlabResult.qReference, ...
                    saved.runs(index).simulinkResult.qReference);
                testCase.verifyEqual( ...
                    saved.runs(index).matlabResult.dqReference, ...
                    saved.runs(index).simulinkResult.dqReference);
            end
        end
    end
end
