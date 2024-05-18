// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../BaseProposal.sol";
import "../ParticipantTypes/IEligibility.sol";
import "../ParticipantTypes/EmailEligibility.sol";
import "../Types.sol";

contract STVProposal is BaseProposal {
    IEligibility public eligibilityContract;

    error AlreadyVoted();

    struct Ballot {
        uint256[] preferences;
    }

    mapping(address => Ballot) private ballots;
    mapping(uint256 => uint256) public currentRoundVotes;
    uint256 public quota;

    constructor(
        address _eligibilityContract,
        uint256 _proposalLength,
        string memory _proposalName,
        string memory _proposalDescription,
        Types.EligibilityType _eligibilityType,
        string[] memory _candidateNames,
        string[] memory _candidateDescriptions,
        string[] memory _candidatePhotos
    ) {
        eligibilityContract = IEligibility(_eligibilityContract);
        proposalLength = _proposalLength;
        startTime = block.timestamp;
        proposalName = _proposalName;
        proposalDescription = _proposalDescription;
        eligibilityType = _eligibilityType;
        proposalType = Types.ProposalType.STV;

        for (uint256 i = 0; i < _candidateNames.length; i++) {
            addCandidate(_candidateNames[i], _candidateDescriptions[i], _candidatePhotos[i]);
        }

        quota = calculateQuota();
    }

    function isEligible(address _voter, bytes32 _votingID) public view override returns (bool) {
        return eligibilityContract.isEligible(_voter, _votingID);
    }

    function vote(uint256[] calldata _candidateIds, bytes32 _votingID) public override onlyEligibleVoters(_votingID) withinVotingPeriod {
        if (hasVoted[msg.sender]) {
            revert AlreadyVoted();
        }
        for (uint256 i = 0; i < _candidateIds.length; i++) {
            if (_candidateIds[i] >= candidateCount) {
                revert Types.InvalidCandidate();
            }
        }

        ballots[msg.sender] = Ballot(_candidateIds);
        currentRoundVotes[_candidateIds[0]]++;
        hasVoted[msg.sender] = true;

        if (eligibilityType == Types.EligibilityType.Email) {
            EmailEligibility(address(eligibilityContract)).useVotingID(_votingID);
        }
    }

    // Placeholder function, STV requires multiple _candidateIds
    function vote(uint256 _candidateId, bytes32 _votingID) public override {}

    function calculateQuota() internal view returns (uint256) {
        // Example quota calculation using Droop quota: (Total Votes / (Seats + 1)) + 1
        // For simplicity, assuming 1 seat. Adjust accordingly for multiple seats.
        uint256 totalVotes = 0;
        for (uint256 i = 0; i < candidateCount; i++) {
            totalVotes += currentRoundVotes[i];
        }
        return (totalVotes / (1 + 1)) + 1;
    }

    function declareWinner() public override {
        require(hasVotingEnded(), "Voting period has not ended yet");

        uint256 totalVotes;
        for (uint256 i = 0; i < candidateCount; i++) {
            totalVotes += currentRoundVotes[i];
        }

        while (true) {
            // Check if any candidate has reached the quota
            for (uint256 i = 0; i < candidateCount; i++) {
                if (currentRoundVotes[i] >= quota) {
                    winnerCandidateId = i;
                    winnerDeclared = true;
                    return;
                }
            }

            // Find the candidate with the fewest votes
            uint256 minVotes = totalVotes;
            uint256 minCandidateId;
            bool minCandidateFound = false;
            for (uint256 i = 0; i < candidateCount; i++) {
                if (currentRoundVotes[i] > 0 && currentRoundVotes[i] < minVotes) {
                    minVotes = currentRoundVotes[i];
                    minCandidateId = i;
                    minCandidateFound = true;
                }
            }

            if (!minCandidateFound) {
                // No candidates left with votes, declare a draw or handle accordingly
                revert("No candidates with votes remaining, cannot declare a winner");
            }

            // Redistribute votes from the candidate with the fewest votes
            for (uint256 i = 0; i < candidateCount; i++) {
                if (currentRoundVotes[i] == minVotes) {
                    currentRoundVotes[i] = 0; // Eliminate the candidate
                    for (uint256 j = 0; j < candidateCount; j++) {
                        if (ballots[msg.sender].preferences[0] == i) {
                            // Shift preferences to remove the eliminated candidate
                            for (uint256 k = 1; k < ballots[msg.sender].preferences.length; k++) {
                                ballots[msg.sender].preferences[k - 1] = ballots[msg.sender].preferences[k];
                            }
                            ballots[msg.sender].preferences.pop();
                            currentRoundVotes[ballots[msg.sender].preferences[0]]++;
                        }
                    }
                }
            }
        }
    }
}
