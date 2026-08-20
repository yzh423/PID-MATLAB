classdef TestCartesianTasks < matlab.unittest.TestCase
    methods (Test)
        function smokeModeCreatesFairCompleteArtifactSet(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            outputRoot = tempname;
            mkdir(outputRoot);
            testCase.addTeardown(@() rmdir(outputRoot,"s"));
            cartesianMode = "smoke"; %#ok<NASGU>

            run(fullfile(projectRoot,"experiments", ...
                "run_cartesian_tasks.m"));

            dataDirectory = fullfile(outputRoot,"data");
            figureDirectory = fullfile(outputRoot,"figures");
            requiredData = ["cartesian_tasks.mat", ...
                "cartesian_tasks_runs.csv"];
            for fileName = requiredData
                file = dir(fullfile(dataDirectory,fileName));
                testCase.verifyEqual(numel(file),1);
                testCase.verifyGreaterThan(file.bytes,0);
            end
            figureNames = ["paths","errors","joint_references", ...
                "torque","summary"];
            for figureName = figureNames
                file = dir(fullfile(figureDirectory, ...
                    "cartesian_tasks_"+figureName+".png"));
                testCase.verifyEqual(numel(file),1);
                testCase.verifyGreaterThan(file.bytes,0);
            end

            saved = load(fullfile(dataDirectory,"cartesian_tasks.mat"));
            testCase.verifyEqual(height(saved.runTable),6);
            testCase.verifyEqual(numel(saved.runs),6);
            testCase.verifyEqual(numel(saved.tasks),2);
            pairs = saved.runTable.Task+"|"+saved.runTable.Controller;
            testCase.verifyEqual(numel(unique(pairs)),6);
            testCase.verifyTrue(all(saved.runTable.Status == "completed"));
            finiteColumns = ["CartesianRms","CartesianMax", ...
                "JointRmsMean","TorqueRmsMean","TotalSaturationTime"];
            testCase.verifyTrue(all(isfinite( ...
                saved.runTable{:,finiteColumns}),"all"));
            straightRows = saved.runTable.Task == "straight-line";
            testCase.verifyTrue(all(isnan( ...
                saved.runTable.PickupError(straightRows))));
            testCase.verifyTrue(all(isnan( ...
                saved.runTable.PlaceError(straightRows))));
            pickRows = saved.runTable.Task == "pick-transfer-place";
            testCase.verifyTrue(all(isfinite( ...
                saved.runTable.PickupError(pickRows))));
            testCase.verifyTrue(all(isfinite( ...
                saved.runTable.PlaceError(pickRows))));

            for taskName = unique(saved.runTable.Task,"stable").'
                taskRuns = saved.runs([saved.runs.taskName] == taskName);
                testCase.verifyEqual(numel(taskRuns),3);
                for runIndex = 2:3
                    testCase.verifyEqual( ...
                        taskRuns(runIndex).result.qReference, ...
                        taskRuns(1).result.qReference);
                    testCase.verifyEqual( ...
                        taskRuns(runIndex).result.dqReference, ...
                        taskRuns(1).result.dqReference);
                end
            end

            robot = saved.robot;
            expectedControllers = { ...
                rrm.config.makePidController(robot), ...
                rrm.config.makeFuzzyPidController(robot), ...
                rrm.config.makeOptimizedPidController(robot)};
            for controllerIndex = 1:3
                actual = saved.controllerDefinitions(controllerIndex).controller;
                expected = expectedControllers{controllerIndex};
                testCase.verifyEqual(actual.Kp,expected.Kp);
                testCase.verifyEqual(actual.Ki,expected.Ki);
                testCase.verifyEqual(actual.Kd,expected.Kd);
            end
        end
    end
end
