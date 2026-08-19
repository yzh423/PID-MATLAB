function [solutions, reachable] = inverse(robot, position)
%INVERSE Compute both analytical planar inverse-kinematics branches.
arguments
    robot (1,1) struct
    position double {mustBeFinite, mustBeReal}
end

if ~isequal(size(position), [2 1])
    error("MATLAB:validation:IncompatibleSize", ...
        "Position must be a 2-by-1 column vector.");
end

x = position(1);
y = position(2);
c2 = (x^2 + y^2 - robot.L1^2 - robot.L2^2) / ...
    (2*robot.L1*robot.L2);
tolerance = 1e-12;

if abs(c2) > 1 + tolerance
    solutions = NaN(2, 2);
    reachable = false;
    return
end

c2 = min(1, max(-1, c2));
s2Magnitude = sqrt(max(0, 1 - c2^2));
s2 = [s2Magnitude, -s2Magnitude];
q2 = atan2(s2, c2);
q1 = atan2(y, x) - atan2(robot.L2*s2, robot.L1 + robot.L2*c2);

solutions = [q1; q2];
reachable = true;
end
