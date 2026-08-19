function result = runPid(robot, controller, reference, options)
%RUNPID Simulate a PID controller through the shared controller path.
result = rrm.simulation.runController( ...
    robot, controller, reference, options);
end
