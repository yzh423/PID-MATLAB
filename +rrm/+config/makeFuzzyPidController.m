function controller = makeFuzzyPidController(robot)
%MAKEFUZZYPIDCONTROLLER Create the bounded Mamdani Fuzzy-PID controller.
arguments
    robot (1,1) struct
end

controller = rrm.config.makePidController(robot);
controller.name = "mamdani-fuzzy-pid";
controller.type = "fuzzy-pid";
controller.errorScale = deg2rad(20)*ones(2,1);
controller.errorRateScale = deg2rad(60)*ones(2,1);
controller.correctionFraction = struct( ...
    "Kp", 0.35, "Ki", 0.50, "Kd", 0.30);

controller.rules = struct( ...
    "Kp", [5 5 5 5 5; 4 4 4 4 4; 4 3 2 3 4; ...
        4 4 4 4 4; 5 5 5 5 5], ...
    "Ki", [1 1 1 1 1; 2 2 3 2 2; 2 4 5 4 2; ...
        2 2 3 2 2; 1 1 1 1 1], ...
    "Kd", repmat([5 4 3 4 5], 5, 1));

controller.outputUniverse = linspace(-1, 1, 101);
controller.outputMembership = zeros(5, 101);
for sample = 1:numel(controller.outputUniverse)
    controller.outputMembership(:,sample) = ...
        rrm.fuzzy.membershipFive(controller.outputUniverse(sample));
end

gainNames = ["Kp", "Ki", "Kd"];
lower = struct();
upper = struct();
for gainName = gainNames
    fraction = controller.correctionFraction.(gainName);
    lower.(gainName) = controller.(gainName).*(1-fraction);
    upper.(gainName) = controller.(gainName).*(1+fraction);
end
controller.gainBounds = struct("lower", lower, "upper", upper);
end
