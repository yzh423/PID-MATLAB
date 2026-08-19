classdef TestStochasticRobustness < matlab.unittest.TestCase
    methods (Test)
        function smokeModeCreatesCompleteArtifactSet(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            outputRoot = tempname;
            mkdir(outputRoot);
            testCase.addTeardown(@() rmdir(outputRoot,"s"));
            stochasticMode = "smoke";

            run(fullfile(projectRoot,"experiments", ...
                "run_stochastic_robustness.m"));

            dataDirectory = fullfile(outputRoot,"data");
            figureDirectory = fullfile(outputRoot,"figures");
            testCase.verifyEqual(exist(fullfile(dataDirectory, ...
                "stochastic_robustness.mat"),"file"),2);
            testCase.verifyEqual(exist(fullfile(dataDirectory, ...
                "stochastic_robustness_trials.csv"),"file"),2);
            testCase.verifyEqual(exist(fullfile(dataDirectory, ...
                "stochastic_robustness_summary.csv"),"file"),2);
            figureNames = ["success","accuracy","chattering", ...
                "saturation","combined","representative"];
            for figureName = figureNames
                testCase.verifyEqual(exist(fullfile(figureDirectory, ...
                    "stochastic_robustness_" + figureName + ".png"), ...
                    "file"),2);
            end

            saved = load(fullfile(dataDirectory, ...
                "stochastic_robustness.mat"));
            testCase.verifyEqual(saved.stochasticMode,"smoke");
            testCase.verifyEqual(height(saved.trialTable),12);
            testCase.verifyEqual(height(saved.summaryTable),6);
            testCase.verifyEqual(numel(saved.representativeRuns),6);
            keys = saved.trialTable.Scenario + "|" + ...
                saved.trialTable.Controller + "|" + ...
                string(saved.trialTable.Trial) + "|" + ...
                string(saved.trialTable.Seed);
            testCase.verifyEqual(numel(unique(keys)),12);
            testCase.verifyEqual(numel(saved.nominalReferenceRuns),3);
            testCase.verifyTrue(all([saved.nominalReferenceRuns.success]));
        end
    end
end
