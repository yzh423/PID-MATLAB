function membership = membershipFive(value)
%MEMBERSHIPFIVE Evaluate NB, NS, Z, PS, and PB memberships.
arguments
    value (1,1) double {mustBeFinite, mustBeReal}
end

normalizedValue = max(-1, min(1, value));
centres = (-1:0.5:1).';
membership = max(1 - abs(normalizedValue - centres)/0.5, 0);
end
