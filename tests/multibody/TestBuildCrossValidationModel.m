classdef TestBuildCrossValidationModel < matlab.unittest.TestCase
    methods (Test)
        function buildsStandalonePhysicalShell(testCase)
            directory = tempname;
            mkdir(directory);
            testCase.addTeardown(@() removeDirectory(directory));
            modelPath = fullfile(directory,"rrm_mb_shell_test.slx");

            modelName = rrm.multibody.buildCrossValidationModel(modelPath);
            cleanup = onCleanup(@() closeLoadedModel(modelName)); %#ok<NASGU>

            testCase.verifyTrue(isfile(modelPath));
            testCase.verifyEqual(string(get_param(modelName,"Solver")),"ode4");
            testCase.verifyEqual(string(get_param( ...
                modelName,"SolverType")),"Fixed-step");
            testCase.verifyEqual(string(get_param( ...
                modelName,"FixedStep")),"0.001");
            required = ["Reference","PID Controller", ...
                "Multibody Plant","Logging"];
            for name = required
                testCase.verifyNotEmpty(find_system(modelName, ...
                    "SearchDepth",1,"Name",name));
            end
            testCase.verifyNotEmpty(find_system( ...
                modelName+"/Reference","SearchDepth",1, ...
                "Name","q Reference"));
            testCase.verifyNotEmpty(find_system( ...
                modelName+"/PID Controller","SearchDepth",1, ...
                "Name","Torque Limit"));
        end

        function rebuildIsIdempotent(testCase)
            directory = tempname;
            mkdir(directory);
            testCase.addTeardown(@() removeDirectory(directory));
            modelPath = fullfile(directory,"rrm_mb_rebuild_test.slx");

            firstName = rrm.multibody.buildCrossValidationModel(modelPath);
            closeLoadedModel(firstName);
            secondName = rrm.multibody.buildCrossValidationModel(modelPath);
            cleanup = onCleanup(@() closeLoadedModel(secondName)); %#ok<NASGU>

            testCase.verifyEqual(secondName,firstName);
            testCase.verifyTrue(isfile(modelPath));
        end

        function rejectsNonSlxPath(testCase)
            testCase.verifyError(@() ...
                rrm.multibody.buildCrossValidationModel("invalid.mat"), ...
                "rrm:multibody:InvalidModelPath");
        end

        function relativePathResolvesUnderProjectRoot(testCase)
            relativePath = fullfile("models","rrm_mb_relative_test.slx");
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            expectedPath = fullfile(projectRoot,relativePath);
            fileCleanup = onCleanup( ...
                @() deleteIfPresent(expectedPath)); %#ok<NASGU>
            temporaryCurrentFolder = tempname;
            mkdir(temporaryCurrentFolder);
            originalFolder = cd(temporaryCurrentFolder);
            currentFolderCleanup = onCleanup(@() restoreAndRemove( ...
                originalFolder,temporaryCurrentFolder)); %#ok<NASGU>

            modelName = rrm.multibody.buildCrossValidationModel(relativePath);

            testCase.verifyTrue(isfile(expectedPath));
            testCase.verifyFalse(isfile(fullfile( ...
                temporaryCurrentFolder,relativePath)));
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
