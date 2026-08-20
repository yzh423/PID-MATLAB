function Jdot = jacobianDot(robot,q,dq)
%JACOBIANDOT Compute the time derivative of the planar Jacobian.
arguments
    robot (1,1) struct
    q (2,1) double {mustBeFinite,mustBeReal}
    dq (2,1) double {mustBeFinite,mustBeReal}
end

q12 = q(1) + q(2);
dq12 = dq(1) + dq(2);
Jdot = [ ...
    -robot.L1*cos(q(1))*dq(1)-robot.L2*cos(q12)*dq12, ...
    -robot.L2*cos(q12)*dq12; ...
    -robot.L1*sin(q(1))*dq(1)-robot.L2*sin(q12)*dq12, ...
    -robot.L2*sin(q12)*dq12];
end
