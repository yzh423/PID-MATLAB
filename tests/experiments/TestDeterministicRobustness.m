classdef TestDeterministicRobustness < matlab.unittest.TestCase
    methods (Test)
        function smokeModeCreatesCompleteArtifactSet(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            outputRoot = tempname;
            mkdir(outputRoot);
            testCase.addTeardown(@() rmdir(outputRoot,"s"));
            robustnessMode = "smoke"; %#ok<NASGU>

            run(fullfile(projectRoot,"experiments", ...
                "run_deterministic_robustness.m"));

            dataDirectory = fullfile(outputRoot,"data");
            figureDirectory = fullfile(outputRoot,"figures");
            testCase.verifyEqual(exist(fullfile(dataDirectory, ...
                "deterministic_robustness.mat"),"file"), 2);
            testCase.verifyEqual(exist(fullfile(dataDirectory, ...
                "deterministic_robustness_runs.csv"),"file"), 2);
            testCase.verifyEqual(exist(fullfile(dataDirectory, ...
                "deterministic_robustness_summary.csv"),"file"), 2);
            figureNames = ["payload","configuration","uncertainty", ...
                "disturbance","heatmap","summary"];
            for figureName = figureNames
                testCase.verifyEqual(exist(fullfile(figureDirectory, ...
                    "deterministic_robustness_" + figureName + ".png"), ...
                    "file"), 2);
            end

            saved = load(fullfile(dataDirectory, ...
                "deterministic_robustness.mat"));
            testCase.verifyEqual(height(saved.runTable), 12);
            testCase.verifyEqual(height(saved.summaryTable), 3);
            pairs = saved.runTable.Scenario + "|" + ...
                saved.runTable.Controller;
            testCase.verifyEqual(numel(unique(pairs)), 12);
            nominal = saved.runTable.Scenario == "nominal";
            testCase.verifyTrue(all(saved.runTable.Success(nominal)));
        end
    end
end
