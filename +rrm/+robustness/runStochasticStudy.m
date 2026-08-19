function study = runStochasticStudy( ...
        controllerDefinitions, scenarios, reference, criteria)
%RUNSTOCHASTICSTUDY Execute paired seeded trials for frozen controllers.
arguments
    controllerDefinitions struct
    scenarios struct
    reference (1,1) struct
    criteria (1,1) struct
end

validateStudy(controllerDefinitions,scenarios);
controllerCount = numel(controllerDefinitions);
runCount = controllerCount*sum(arrayfun( ...
    @(scenario) numel(scenario.seeds),scenarios));
representativeCount = controllerCount*numel(scenarios);
representativeRuns = repmat(struct( ...
    "scenarioName","","controllerName","","trial",NaN,"seed",NaN, ...
    "scenario",struct(),"controller",struct(),"result",struct(), ...
    "metrics",struct()),representativeCount,1);

Scenario = strings(runCount,1);
Category = strings(runCount,1);
Controller = strings(runCount,1);
Trial = zeros(runCount,1);
Seed = zeros(runCount,1);
Status = strings(runCount,1);
Success = false(runCount,1);
JointRms1 = NaN(runCount,1);
JointRms2 = NaN(runCount,1);
JointRmsMean = NaN(runCount,1);
EndEffectorRms = NaN(runCount,1);
EndEffectorMax = NaN(runCount,1);
TrackingErrorVariance1 = NaN(runCount,1);
TrackingErrorVariance2 = NaN(runCount,1);
TrackingErrorVarianceMean = NaN(runCount,1);
TorqueSlew1 = NaN(runCount,1);
TorqueSlew2 = NaN(runCount,1);
TorqueSlewMean = NaN(runCount,1);
ControlEnergy = NaN(runCount,1);
TotalSaturationTime = NaN(runCount,1);
RecoveryTime = NaN(runCount,1);
PositionNoiseStdDeg = NaN(runCount,1);
VelocityNoiseStdDegPerSec = NaN(runCount,1);
PositionNoiseRms = NaN(runCount,1);
VelocityNoiseRms = NaN(runCount,1);
Payload = NaN(runCount,1);
UncertaintyScale = NaN(runCount,1);
TorqueScale = NaN(runCount,1);

row = 0;
representativeIndex = 0;
sampleCount = numel(reference.time);
for scenarioIndex = 1:numel(scenarios)
    scenario = scenarios(scenarioIndex);
    for trialIndex = 1:numel(scenario.seeds)
        seed = scenario.seeds(trialIndex);
        noise = rrm.robustness.makeMeasurementNoise( ...
            scenario.noise,sampleCount,seed);
        options = scenario.options;
        options.measurementNoise = rmfield(noise,"seed");
        positionNoiseRms = sqrt(mean(noise.position.^2,"all"));
        velocityNoiseRms = sqrt(mean(noise.velocity.^2,"all"));
        for controllerIndex = 1:controllerCount
            definition = controllerDefinitions(controllerIndex);
            row = row + 1;
            try
                result = rrm.simulation.runController( ...
                    scenario.robot,definition.controller,reference,options);
                metrics = rrm.robustness.evaluateStochasticRun( ...
                    result,scenario.robot,criteria,scenario);
            catch exception
                context = MException("rrm:robustness:StochasticRunFailed", ...
                    "Scenario %s, controller %s, trial %d, seed %d failed.", ...
                    scenario.name,definition.name,trialIndex,seed);
                context = addCause(context,exception);
                throw(context)
            end

            if trialIndex == 1
                representativeIndex = representativeIndex + 1;
                representativeRuns(representativeIndex) = struct( ...
                    "scenarioName",scenario.name, ...
                    "controllerName",definition.name, ...
                    "trial",trialIndex, ...
                    "seed",seed, ...
                    "scenario",scenario, ...
                    "controller",definition.controller, ...
                    "result",result, ...
                    "metrics",metrics);
            end

            robustness = metrics.robustness;
            common = robustness.common;
            Scenario(row) = scenario.name;
            Category(row) = scenario.category;
            Controller(row) = definition.name;
            Trial(row) = trialIndex;
            Seed(row) = seed;
            Status(row) = result.status;
            Success(row) = robustness.success;
            JointRms1(row) = common.rmsError(1);
            JointRms2(row) = common.rmsError(2);
            JointRmsMean(row) = mean(common.rmsError);
            EndEffectorRms(row) = robustness.endEffectorRmsError;
            EndEffectorMax(row) = robustness.endEffectorMaxError;
            TrackingErrorVariance1(row) = metrics.trackingErrorVariance(1);
            TrackingErrorVariance2(row) = metrics.trackingErrorVariance(2);
            TrackingErrorVarianceMean(row) = ...
                mean(metrics.trackingErrorVariance);
            TorqueSlew1(row) = metrics.torqueSlewRms(1);
            TorqueSlew2(row) = metrics.torqueSlewRms(2);
            TorqueSlewMean(row) = metrics.torqueSlewMean;
            ControlEnergy(row) = common.controlEnergy;
            TotalSaturationTime(row) = robustness.totalSaturationTime;
            RecoveryTime(row) = robustness.recoveryTime;
            PositionNoiseStdDeg(row) = rad2deg(mean( ...
                scenario.noise.positionStd));
            VelocityNoiseStdDegPerSec(row) = rad2deg(mean( ...
                scenario.noise.velocityStd));
            PositionNoiseRms(row) = positionNoiseRms;
            VelocityNoiseRms(row) = velocityNoiseRms;
            Payload(row) = scenario.payload;
            UncertaintyScale(row) = scenario.uncertaintyScale;
            TorqueScale(row) = scenario.torqueScale;
        end
    end
end

trialTable = table(Scenario,Category,Controller,Trial,Seed,Status,Success, ...
    JointRms1,JointRms2,JointRmsMean,EndEffectorRms,EndEffectorMax, ...
    TrackingErrorVariance1,TrackingErrorVariance2, ...
    TrackingErrorVarianceMean,TorqueSlew1,TorqueSlew2,TorqueSlewMean, ...
    ControlEnergy,TotalSaturationTime,RecoveryTime,PositionNoiseStdDeg, ...
    VelocityNoiseStdDegPerSec,PositionNoiseRms,VelocityNoiseRms, ...
    Payload,UncertaintyScale,TorqueScale);
study = struct("table",trialTable, ...
    "representativeRuns",representativeRuns);
end

function validateStudy(definitions,scenarios)
if isempty(definitions) || ...
        ~all(isfield(definitions,["name","controller"]))
    invalidStudy("Controller definitions are incomplete.");
end
controllerNames = string({definitions.name});
hasType = arrayfun(@(definition) ...
    isfield(definition.controller,"type"),definitions);
if numel(unique(controllerNames)) ~= numel(controllerNames) || ...
        any(strlength(controllerNames) == 0) || ~all(hasType)
    invalidStudy("Controller definitions must be unique and typed.");
end
requiredScenarioFields = ["name","category","robot","options", ...
    "noise","seeds","disturbanceWindow","recoveryBand", ...
    "recoveryDwell","payload","uncertaintyScale","torqueScale"];
if isempty(scenarios) || ...
        ~all(isfield(scenarios,requiredScenarioFields)) || ...
        numel(unique([scenarios.name])) ~= numel(scenarios)
    invalidStudy("Scenarios must be complete and uniquely named.");
end
for index = 1:numel(scenarios)
    seeds = scenarios(index).seeds;
    validSeeds = isnumeric(seeds) && isreal(seeds) && isvector(seeds) && ...
        ~isempty(seeds) && all(isfinite(seeds)) && all(seeds >= 0) && ...
        all(seeds == floor(seeds)) && numel(unique(seeds)) == numel(seeds);
    if ~validSeeds
        invalidStudy("Every scenario needs unique nonnegative seeds.");
    end
end
end

function invalidStudy(message)
error("rrm:robustness:InvalidStochasticStudy","%s",message);
end
