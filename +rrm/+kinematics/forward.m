function position = forward(robot, q)
%FORWARD Compute planar end-effector position from joint angles.
arguments
    robot (1,1) struct
    q double {mustBeFinite, mustBeReal}
end

if ~isequal(size(q), [2 1])
    error("MATLAB:validation:IncompatibleSize", ...
        "Joint vector q must be a 2-by-1 column vector.");
end

q12 = q(1) + q(2);
position = [
    robot.L1*cos(q(1)) + robot.L2*cos(q12);
    robot.L1*sin(q(1)) + robot.L2*sin(q12)
];
end
