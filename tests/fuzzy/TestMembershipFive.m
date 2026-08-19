classdef TestMembershipFive < matlab.unittest.TestCase
    methods (Test)
        function namedSetsPeakAtTheirCentres(testCase)
            testCase.verifyEqual( ...
                rrm.fuzzy.membershipFive(-1), [1;0;0;0;0], AbsTol=1e-14);
            testCase.verifyEqual( ...
                rrm.fuzzy.membershipFive(0), [0;0;1;0;0], AbsTol=1e-14);
            testCase.verifyEqual( ...
                rrm.fuzzy.membershipFive(1), [0;0;0;0;1], AbsTol=1e-14);
        end

        function membershipsFormNonnegativePartition(testCase)
            for value = linspace(-1, 1, 17)
                membership = rrm.fuzzy.membershipFive(value);
                testCase.verifySize(membership, [5 1]);
                testCase.verifyGreaterThanOrEqual(membership, 0);
                testCase.verifyEqual(sum(membership), 1, AbsTol=1e-14);
            end
        end

        function inputsAreClampedToNormalizedUniverse(testCase)
            testCase.verifyEqual( ...
                rrm.fuzzy.membershipFive(-4), [1;0;0;0;0], AbsTol=1e-14);
            testCase.verifyEqual( ...
                rrm.fuzzy.membershipFive(3), [0;0;0;0;1], AbsTol=1e-14);
        end

        function invalidInputIsRejected(testCase)
            testCase.verifyError( ...
                @() rrm.fuzzy.membershipFive([0 1]), ...
                "MATLAB:validation:IncompatibleSize");
        end
    end
end
