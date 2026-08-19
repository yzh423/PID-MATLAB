function ddq = acceleration(robot, q, dq, tau, disturbance)
%ACCELERATION Compute joint acceleration for applied torque.
arguments
    robot (1,1) struct
    q double {mustBeFinite, mustBeReal}
    dq double {mustBeFinite, mustBeReal}
    tau double {mustBeFinite, mustBeReal}
    disturbance double {mustBeFinite, mustBeReal} = zeros(2,1)
end

mustBeTwoElementColumn(q, "q");
mustBeTwoElementColumn(dq, "dq");
mustBeTwoElementColumn(tau, "tau");
mustBeTwoElementColumn(disturbance, "disturbance");

[M, C, G] = rrm.dynamics.matrices(robot, q, dq);
frictionTorque = robot.viscousFriction .* dq;
ddq = M \ (tau + disturbance - C*dq - G - frictionTorque);
end

function mustBeTwoElementColumn(value, name)
if ~isequal(size(value), [2 1])
    error("rrm:dynamics:InvalidVector", ...
        "%s must be a 2-by-1 column vector.", name);
end
end
