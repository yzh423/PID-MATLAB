classdef TestBuildPidCrossValidationModel < matlab.unittest.TestCase
    methods (Test)
        function buildsLoadableOrganizedModel(testCase)
            root = tempname;
            mkdir(root);
            cleanup = onCleanup(@() removeDirectory(root)); %#ok<NASGU>
            modelPath = fullfile(root,"cross_validation.slx");

            modelName = rrm.simulink.buildPidCrossValidationModel(modelPath);

            testCase.verifyTrue(isfile(modelPath));
            load_system(modelPath);
            modelCleanup = onCleanup( ...
                @() closeLoadedModel(modelName)); %#ok<NASGU>
            testCase.verifyEqual(string(get_param(modelName,"Solver")),"ode4");
            testCase.verifyEqual( ...
                str2double(get_param(modelName,"FixedStep")),0.001);
            testCase.verifyEqual( ...
                string(get_param(modelName,"SolverType")),"Fixed-step");
            required = ["Reference","PID Controller", ...
                "Two-Link Plant","Logging"];
            for blockName = required
                matches = find_system(modelName, ...
                    "SearchDepth",1,"Name",blockName);
                testCase.verifyNumElements(matches,1);
            end
        end

        function builderIsIdempotent(testCase)
            root = tempname;
            mkdir(root);
            cleanup = onCleanup(@() removeDirectory(root)); %#ok<NASGU>
            modelPath = fullfile(root,"repeatable.slx");

            firstName = rrm.simulink.buildPidCrossValidationModel(modelPath);
            secondName = rrm.simulink.buildPidCrossValidationModel(modelPath);

            testCase.verifyEqual(secondName,firstName);
            testCase.verifyTrue(isfile(modelPath));
            closeLoadedModel(firstName);
        end

        function modelContainsNativeClosedLoopAndCompiles(testCase)
            root = tempname;
            mkdir(root);
            cleanup = onCleanup(@() removeDirectory(root)); %#ok<NASGU>
            modelPath = fullfile(root,"structured.slx");
            modelName = rrm.simulink.buildPidCrossValidationModel(modelPath);
            load_system(modelPath);
            modelCleanup = onCleanup( ...
                @() closeLoadedModel(modelName)); %#ok<NASGU>

            controllerBlocks = ["Error","Rate Error","Derivative Filter", ...
                "Integral State","Unsaturated Torque","Torque Limit"];
            for blockName = controllerBlocks
                matches = find_system(modelName + "/PID Controller", ...
                    "SearchDepth",1,"Name",blockName);
                testCase.verifyNumElements(matches,1);
            end
            plantBlocks = ["Dynamics","Joint Position","Joint Velocity"];
            for blockName = plantBlocks
                matches = find_system(modelName + "/Two-Link Plant", ...
                    "SearchDepth",1,"Name",blockName);
                testCase.verifyNumElements(matches,1);
            end
            chart = find(sfroot,"-isa","Stateflow.EMChart", ...
                "Path",modelName + "/Two-Link Plant/Dynamics");
            testCase.verifyNumElements(chart,1);
            testCase.verifyFalse(contains(chart.Script,"rrm.dynamics"));
            testCase.verifyFalse(contains(chart.Script,"runController"));

            set_param(modelName,"SimulationCommand","update");
            testCase.verifyEqual(string(get_param(modelName,"SimulationStatus")), ...
                "stopped");
        end

        function rejectsNonSlxTarget(testCase)
            testCase.verifyError( ...
                @() rrm.simulink.buildPidCrossValidationModel("bad.txt"), ...
                "rrm:simulink:InvalidModelPath");
        end

        function relativePathUsesProjectRoot(testCase)
            functionPath = which("rrm.config.makeRobot");
            projectRoot = fileparts(fileparts(fileparts(functionPath)));
            relativePath = fullfile("models","relative_contract_test.slx");
            expectedPath = fullfile(projectRoot,relativePath);
            fileCleanup = onCleanup( ...
                @() deleteIfPresent(expectedPath)); %#ok<NASGU>
            temporaryCurrentFolder = tempname;
            mkdir(temporaryCurrentFolder);
            originalFolder = cd(temporaryCurrentFolder);
            currentFolderCleanup = onCleanup(@() restoreAndRemove( ...
                originalFolder,temporaryCurrentFolder)); %#ok<NASGU>

            modelName = rrm.simulink.buildPidCrossValidationModel(relativePath);

            testCase.verifyTrue(isfile(expectedPath));
            testCase.verifyFalse(isfile(fullfile(temporaryCurrentFolder,relativePath)));
            closeLoadedModel(modelName);
        end
    end
end

function closeLoadedModel(modelName)
if bdIsLoaded(modelName)
    close_system(modelName,0);
end
end

function removeDirectory(path)
if isfolder(path)
    rmdir(path,"s");
end
end

function deleteIfPresent(path)
if isfile(path)
    delete(path);
end
end

function restoreAndRemove(originalFolder,temporaryFolder)
cd(originalFolder);
removeDirectory(temporaryFolder);
end
