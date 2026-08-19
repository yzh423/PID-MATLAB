classdef TestQuintic < matlab.unittest.TestCase
    methods (Test)
        function satisfiesEndpointBoundaryConditions(testCase)
            q0 = deg2rad([0; 0]);
            qf = deg2rad([45; 60]);

            reference = rrm.trajectory.quintic(q0, qf, 3, 0.001, 5);

            testCase.verifyEqual(reference.q(:,1), q0, AbsTol=1e-12);
            testCase.verifyEqual(reference.q(:,end), qf, AbsTol=1e-12);
            testCase.verifyLessThan( ...
                max(abs(reference.dq(:,[1 end])), [], "all"), 1e-10);
            testCase.verifyLessThan( ...
                max(abs(reference.ddq(:,[1 end])), [], "all"), 1e-10);
            testCase.verifyEqual(reference.time(end), 5, AbsTol=1e-14);
        end

        function holdsFinalPositionAfterMotion(testCase)
            qf = [0.4; -0.2];
            reference = rrm.trajectory.quintic([0; 0], qf, 1, 0.1, 2);
            holdIndices = reference.time >= 1;

            testCase.verifyEqual( ...
                reference.q(:,holdIndices), ...
                repmat(qf, 1, sum(holdIndices)), AbsTol=1e-12);
            testCase.verifyEqual( ...
                reference.dq(:,holdIndices), ...
                zeros(2, sum(holdIndices)), AbsTol=1e-12);
        end

        function rejectsTotalDurationShorterThanMotion(testCase)
            testCase.verifyError( ...
                @() rrm.trajectory.quintic([0;0], [1;1], 2, 0.01, 1), ...
                "rrm:trajectory:InvalidDuration");
        end
    end
end
