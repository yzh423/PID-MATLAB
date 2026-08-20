classdef TestExportReportEvidence < matlab.unittest.TestCase
    methods (Test)
        function exportsCompleteFormalEvidence(testCase)
            root = projectRoot();
            output = string(tempname) + ".json";
            testCase.addTeardown(@() deleteIfPresent(output));

            evidence = rrm.report.exportEvidence(root,output);

            testCase.verifyTrue(isfile(output));
            testCase.verifyEqual(evidence.schemaVersion,1);
            testCase.verifyEqual(evidence.deterministic.runCount,39);
            testCase.verifyEqual(evidence.stochastic.trialCount,360);
            testCase.verifyEqual(evidence.cartesian.runCount,6);
            testCase.verifyEqual(evidence.simulink.runCount,2);
            testCase.verifyEqual(evidence.multibody.runCount,2);
            testCase.verifyTrue(all(evidence.multibody.agreementPass));
            testCase.verifyTrue(all(evidence.multibody.trackingSuccess));
            testCase.verifyEqual(evidence.multibody.maximumOutOfPlane,0);
        end

        function preservesKnownFormalValues(testCase)
            output = string(tempname) + ".json";
            testCase.addTeardown(@() deleteIfPresent(output));

            evidence = rrm.report.exportEvidence(projectRoot(),output);

            testCase.verifyEqual(evidence.nominal.manualPid.steadyRms, ...
                [0.00126841;0.0137622],"RelTol",5e-6);
            testCase.verifyEqual( ...
                evidence.optimization.objectiveReductionPercent, ...
                7.283,"AbsTol",5e-4);
            testCase.verifyEqual( ...
                [evidence.deterministic.successCount.manualPid; ...
                 evidence.deterministic.successCount.fuzzyPid; ...
                 evidence.deterministic.successCount.optimizedPid], ...
                [8;9;10]);
            testCase.verifyEqual( ...
                [evidence.stochastic.combinedSuccessCount.manualPid; ...
                 evidence.stochastic.combinedSuccessCount.fuzzyPid; ...
                 evidence.stochastic.combinedSuccessCount.optimizedPid], ...
                [0;0;0]);
        end

        function exportsSystemAndControllerProtocol(testCase)
            output = string(tempname) + ".json";
            testCase.addTeardown(@() deleteIfPresent(output));

            evidence = rrm.report.exportEvidence(projectRoot(),output);

            testCase.verifyEqual(evidence.system.linkLengthsM,[0.45;0.35]);
            testCase.verifyEqual(evidence.system.linkMassesKg,[2;1.5]);
            testCase.verifyEqual(evidence.system.payloadKg,0.5);
            testCase.verifyEqual(evidence.system.torqueLimitsNm,[25;15]);
            testCase.verifyEqual(evidence.protocol.sampleTimeS,0.001);
            testCase.verifyEqual( ...
                evidence.protocol.steadyRmsThresholdRad,[0.02;0.02]);
            testCase.verifyEqual(evidence.controllers.manualPid.Kp,[120;100]);
            testCase.verifyEqual(evidence.controllers.optimizedPid.Kp,[240;200]);
            testCase.verifyEqual( ...
                evidence.controllers.fuzzyPid.correctionFraction.Kp,0.35);
        end

        function rejectsMissingFormalArtifact(testCase)
            fixture = makeFixtureWithout("nominal_pid_vs_fuzzy.mat");
            testCase.addTeardown(@() rmdir(fixture,"s"));

            testCase.verifyError(@() rrm.report.exportEvidence( ...
                fixture,fullfile(fixture,"report.json")), ...
                "rrm:report:MissingArtifact");
        end

        function rejectsTruncatedCsvArtifact(testCase)
            fixture = makeFixture();
            testCase.addTeardown(@() rmdir(fixture,"s"));
            csvPath = fullfile(fixture,"results","data", ...
                "deterministic_robustness_runs.csv");
            rows = readtable(csvPath,'TextType','string');
            writetable(rows(1:end-1,:),csvPath);

            testCase.verifyError(@() rrm.report.exportEvidence( ...
                fixture,fullfile(fixture,"report.json")), ...
                "rrm:report:UnexpectedStudyShape");
        end
    end
end

function root = projectRoot()
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
end

function fixture = makeFixtureWithout(filename)
fixture = makeFixture();
delete(fullfile(fixture,"results","data",filename));
end

function fixture = makeFixture()
sourceRoot = projectRoot();
fixture = string(tempname);
mkdir(fullfile(fixture,"results"));
copyfile(fullfile(sourceRoot,"results","data"), ...
    fullfile(fixture,"results","data"));
copyfile(fullfile(sourceRoot,"results","figures"), ...
    fullfile(fixture,"results","figures"));
end

function deleteIfPresent(path)
if isfile(path)
    delete(path);
end
end
