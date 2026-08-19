function controller = makeOptimizedPidController(robot)
%MAKEOPTIMIZEDPIDCONTROLLER Reproduce the verified Phase 3 PID gains.
arguments
    robot (1,1) struct
end

controller = rrm.config.makePidController(robot);
controller.name = "optimization-pid";
controller.Kp = [240;200];
controller.Ki = [79.9554;30.2026];
controller.Kd = [29.3133;18.3972];
controller.source = "phase-3-fmincon";
end
