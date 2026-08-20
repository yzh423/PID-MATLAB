function tree = makeRigidBodyTree(robot)
%MAKERIGIDBODYTREE Reconstruct the planar robot for independent validation.
arguments
    robot (1,1) struct
end

if isempty(which("rigidBodyTree"))
    error("rrm:validation:MissingRoboticsToolbox", ...
        "Robotics System Toolbox is required for rigid-body validation.");
end
validateRobot(robot);

tree = rigidBodyTree("DataFormat","column","MaxNumBodies",3);
tree.Gravity = [0 -robot.gravity 0];

link1 = rigidBody("link1");
joint1 = rigidBodyJoint("joint1","revolute");
joint1.JointAxis = [0 0 1];
setFixedTransform(joint1, eye(4));
link1.Joint = joint1;
link1.Mass = robot.m1;
link1.CenterOfMass = [robot.com(1) 0 0];
link1OriginInertia = robot.inertia(1) + ...
    robot.m1*robot.com(1)^2;
link1.Inertia = [0 link1OriginInertia link1OriginInertia 0 0 0];
addBody(tree, link1, tree.BaseName);

link2 = rigidBody("link2");
joint2 = rigidBodyJoint("joint2","revolute");
joint2.JointAxis = [0 0 1];
setFixedTransform(joint2, trvec2tform([robot.L1 0 0]));
link2.Joint = joint2;
link2.Mass = robot.m2;
link2.CenterOfMass = [robot.com(2) 0 0];
link2OriginInertia = robot.inertia(2) + ...
    robot.m2*robot.com(2)^2;
link2.Inertia = [0 link2OriginInertia link2OriginInertia 0 0 0];
addBody(tree, link2, link1.Name);

payload = rigidBody("payload");
payloadJoint = rigidBodyJoint("payloadJoint","fixed");
setFixedTransform(payloadJoint, trvec2tform([robot.L2 0 0]));
payload.Joint = payloadJoint;
payload.Mass = robot.payload;
payload.CenterOfMass = [0 0 0];
payload.Inertia = zeros(1,6);
addBody(tree, payload, link2.Name);
end

function validateRobot(robot)
required = ["L1","L2","m1","m2","payload","gravity","com","inertia"];
if ~all(isfield(robot, required))
    error("rrm:validation:InvalidRobot", ...
        "Robot must define geometry, mass, payload, gravity, COM, and inertia.");
end
positiveScalars = [robot.L1 robot.L2 robot.m1 robot.m2 robot.gravity];
isValidPayload = isnumeric(robot.payload) && isreal(robot.payload) && ...
    isscalar(robot.payload) && isfinite(robot.payload) && robot.payload >= 0;
if any(~isfinite(positiveScalars)) || any(positiveScalars <= 0) || ...
        ~isValidPayload || ~isequal(size(robot.com),[2 1]) || ...
        ~isequal(size(robot.inertia),[2 1]) || ...
        any(~isfinite(robot.com)) || any(robot.com <= 0) || ...
        any(~isfinite(robot.inertia)) || any(robot.inertia < 0)
    error("rrm:validation:InvalidRobot", ...
        "Robot physical parameters must be finite and physically valid.");
end
end
