function [M, C, G] = matrices(robot, q, dq)
%MATRICES Compute inertia, Coriolis, and gravity terms.
arguments
    robot (1,1) struct
    q double {mustBeFinite, mustBeReal}
    dq double {mustBeFinite, mustBeReal}
end

mustBeTwoElementColumn(q, "q");
mustBeTwoElementColumn(dq, "dq");

L1 = robot.L1;
L2 = robot.L2;
r1 = robot.com(1);
r2 = robot.com(2);
m1 = robot.m1;
m2 = robot.m2;
mp = robot.payload;
I1 = robot.inertia(1);
I2 = robot.inertia(2);

coupling = m2*L1*r2 + mp*L1*L2;
baseInertia = I1 + I2 + m1*r1^2 + ...
    m2*(L1^2 + r2^2) + mp*(L1^2 + L2^2);
distalInertia = I2 + m2*r2^2 + mp*L2^2;
cosQ2 = cos(q(2));
sinQ2 = sin(q(2));

M = [
    baseInertia + 2*coupling*cosQ2, distalInertia + coupling*cosQ2;
    distalInertia + coupling*cosQ2, distalInertia
];

C = [
    -coupling*sinQ2*dq(2), -coupling*sinQ2*(dq(1) + dq(2));
     coupling*sinQ2*dq(1), 0
];

proximalGravity = (m1*r1 + (m2 + mp)*L1) * ...
    robot.gravity*cos(q(1));
distalGravity = (m2*r2 + mp*L2) * ...
    robot.gravity*cos(q(1) + q(2));
G = [proximalGravity + distalGravity; distalGravity];
end

function mustBeTwoElementColumn(value, name)
if ~isequal(size(value), [2 1])
    error("rrm:dynamics:InvalidVector", ...
        "%s must be a 2-by-1 column vector.", name);
end
end
