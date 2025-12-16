// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EscrowMilestones {
    struct Milestone {
        uint256 amount;
        bool submitted;
        bool released;
        string work;
    }

    struct Job {
        address client;
        address freelancer;
        uint256 totalAmount;
        uint256 releasedAmount;
        bool disputed;
        Milestone[] milestones;
    }

    mapping(uint256 => Job) public jobs;
    uint256 public jobCount;

    function createJob(address freelancer, uint256[] calldata milestoneAmounts) external payable returns(uint256) {
        uint256 total;
        for(uint i=0;i<milestoneAmounts.length;i++) total += milestoneAmounts[i];
        require(msg.value == total, "Incorrect funds");

        jobCount++;
        Job storage j = jobs[jobCount];
        j.client = msg.sender;
        j.freelancer = freelancer;
        j.totalAmount = total;

        for(uint i=0;i<milestoneAmounts.length;i++){
            j.milestones.push(Milestone(milestoneAmounts[i], false, false, ""));
        }

        return jobCount;
    }

    function submitWork(uint256 jobId, uint256 milestoneId, string calldata work) external {
        Job storage j = jobs[jobId];
        require(msg.sender == j.freelancer, "Only freelancer");
        require(milestoneId < j.milestones.length, "Invalid milestone");

        if (milestoneId > 0) {
            require(j.milestones[milestoneId - 1].released, "Previous milestone not released");
        }

        Milestone storage m = j.milestones[milestoneId];
        require(!m.submitted, "Already submitted");
        require(!m.released, "Already released");
        m.submitted = true;
        m.work = work;
    }

    function approveMilestone(uint256 jobId, uint256 milestoneId) external {
        Job storage j = jobs[jobId];
        require(msg.sender == j.client, "Only client");
        Milestone storage m = j.milestones[milestoneId];
        require(m.submitted, "Not submitted");
        require(!m.released, "Already released");
        m.released = true;
        j.releasedAmount += m.amount;
        payable(j.freelancer).transfer(m.amount);
    }

    function markDispute(uint256 jobId) external {
        Job storage j = jobs[jobId];
        require(msg.sender == j.client || msg.sender == j.freelancer, "Unauthorized");
        j.disputed = true;
    }

    function getMilestones(uint256 jobId) external view returns(Milestone[] memory) {
        return jobs[jobId].milestones;
    }
}
