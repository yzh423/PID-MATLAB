function J = jacobian(robot,q)
%JACOBIAN Compute the planar end-effector geometric Jacobian.
arguments
    robot (1,1) struct
    q (2,1) double {mustBeFinite,mustBeReal}
end

q12 = q(1) + q(2);
J = [ ...
    -robot.L1*sin(q(1))-robot.L2*sin(q12), -robot.L2*sin(q12); ...
     robot.L1*cos(q(1))+robot.L2*cos(q12),  robot.L2*cos(q12)];
end
