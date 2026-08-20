function report = compareRigidBodyDynamics(robot, states)
%COMPARERIGIDBODYDYNAMICS Compare analytical and toolbox rigid-body terms.
arguments
    robot (1,1) struct
    states (1,1) struct = defaultStateGrid()
end

validateStates(states);
tree = rrm.validation.makeRigidBodyTree(robot);
sampleCount = size(states.q, 2);
massMatrixError = NaN(2,2,sampleCount);
velocityProductError = NaN(2,sampleCount);
gravityError = NaN(2,sampleCount);

for sample = 1:sampleCount
    q = states.q(:,sample);
    dq = states.dq(:,sample);
    [M, C, G] = rrm.dynamics.matrices(robot, q, dq);
    massMatrixError(:,:,sample) = abs(massMatrix(tree,q) - M);
    velocityProductError(:,sample) = abs( ...
        velocityProduct(tree,q,dq) - C*dq);
    gravityError(:,sample) = abs(gravityTorque(tree,q) - G);
end

report = struct( ...
    "sampleCount", sampleCount, ...
    "states", states, ...
    "massMatrixError", massMatrixError, ...
    "velocityProductError", velocityProductError, ...
    "gravityError", gravityError, ...
    "maxMassMatrixError", max(massMatrixError,[],"all"), ...
    "maxVelocityProductError", max(velocityProductError,[],"all"), ...
    "maxGravityError", max(gravityError,[],"all"));
end

function states = defaultStateGrid()
q1 = deg2rad([-120 -45 0 60 135]);
q2 = deg2rad([-100 -30 0 45 110]);
dq1 = [-1.5 0 1.25];
dq2 = [-1.0 0 1.75];
[q1Grid,q2Grid,dq1Grid,dq2Grid] = ndgrid(q1,q2,dq1,dq2);
states = struct( ...
    "q", [q1Grid(:).'; q2Grid(:).'], ...
    "dq", [dq1Grid(:).'; dq2Grid(:).']);
end

function validateStates(states)
if ~all(isfield(states,["q","dq"])) || ...
        ~isnumeric(states.q) || ~isreal(states.q) || ...
        ~isnumeric(states.dq) || ~isreal(states.dq) || ...
        size(states.q,1) ~= 2 || size(states.dq,1) ~= 2 || ...
        isempty(states.q) || size(states.q,2) ~= size(states.dq,2) || ...
        any(~isfinite(states.q),"all") || any(~isfinite(states.dq),"all")
    error("rrm:validation:InvalidStateGrid", ...
        "State grid q and dq must be finite real 2-by-N arrays.");
end
end
