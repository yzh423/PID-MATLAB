function result = runFuzzyPid(robot, controller, reference, options)
%RUNFUZZYPID Simulate a Fuzzy-PID controller through the shared path.
result = rrm.simulation.runController( ...
    robot, controller, reference, options);
end
