// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EscrowMilestones {
    struct Milestone {
        uint256 amount;
        bool submitted;
        bool released;
        bool rejected;
        string workDescription;
        string submittedWork;
        uint256 submittedAt;
        uint256 releasedAt;
    }

    struct Job {
        address client;
        address freelancer;
        uint256 totalAmount;
        uint256 releasedAmount;
        bool disputed;
        bool cancelled;
        string title;
        string description;
        uint256 createdAt;
        Milestone[] milestones;
    }

    mapping(uint256 => Job) public jobs;
    uint256 public jobCount;

    // Events for tracking
    event JobCreated(uint256 indexed jobId, address indexed client, address indexed freelancer, uint256 totalAmount);
    event WorkSubmitted(uint256 indexed jobId, uint256 milestoneId, string work);
    event MilestoneApproved(uint256 indexed jobId, uint256 milestoneId, uint256 amount);
    event MilestoneRejected(uint256 indexed jobId, uint256 milestoneId, string reason);
    event DisputeRaised(uint256 indexed jobId, address raisedBy);
    event DisputeResolved(uint256 indexed jobId, bool clientFavored);
    event JobCancelled(uint256 indexed jobId);

    modifier onlyClient(uint256 jobId) {
        require(msg.sender == jobs[jobId].client, "Only client");
        _;
    }

    modifier onlyFreelancer(uint256 jobId) {
        require(msg.sender == jobs[jobId].freelancer, "Only freelancer");
        _;
    }

    modifier jobNotDisputed(uint256 jobId) {
        require(!jobs[jobId].disputed, "Job is disputed");
        _;
    }

    modifier jobNotCancelled(uint256 jobId) {
        require(!jobs[jobId].cancelled, "Job is cancelled");
        _;
    }

    function createJob(
        address freelancer,
        uint256[] calldata milestoneAmounts,
        string[] calldata milestoneDescriptions,
        string calldata title,
        string calldata description
    ) external payable returns(uint256) {
        require(freelancer != address(0), "Invalid freelancer address");
        require(freelancer != msg.sender, "Client cannot be freelancer");
        require(milestoneAmounts.length > 0, "Need at least one milestone");
        require(milestoneAmounts.length == milestoneDescriptions.length, "Mismatched arrays");

        uint256 total;
        for(uint i = 0; i < milestoneAmounts.length; i++) {
            require(milestoneAmounts[i] > 0, "Milestone amount must be > 0");
            total += milestoneAmounts[i];
        }
        require(msg.value == total, "Incorrect funds");

        jobCount++;
        Job storage j = jobs[jobCount];
        j.client = msg.sender;
        j.freelancer = freelancer;
        j.totalAmount = total;
        j.title = title;
        j.description = description;
        j.createdAt = block.timestamp;

        for(uint i = 0; i < milestoneAmounts.length; i++){
            j.milestones.push(Milestone({
                amount: milestoneAmounts[i],
                submitted: false,
                released: false,
                rejected: false,
                workDescription: milestoneDescriptions[i],
                submittedWork: "",
                submittedAt: 0,
                releasedAt: 0
            }));
        }

        emit JobCreated(jobCount, msg.sender, freelancer, total);
        return jobCount;
    }

    function submitWork(uint256 jobId, uint256 milestoneId, string calldata work) 
        external 
        onlyFreelancer(jobId)
        jobNotDisputed(jobId)
        jobNotCancelled(jobId)
    {
        Job storage j = jobs[jobId];
        require(milestoneId < j.milestones.length, "Invalid milestone");

        // Check previous milestone is released (except for first milestone)
        if (milestoneId > 0) {
            require(j.milestones[milestoneId - 1].released, "Previous milestone not released");
        }

        Milestone storage m = j.milestones[milestoneId];
        require(!m.released, "Already released");
        require(bytes(work).length > 0, "Work description required");
        
        m.submitted = true;
        m.rejected = false;
        m.submittedWork = work;
        m.submittedAt = block.timestamp;

        emit WorkSubmitted(jobId, milestoneId, work);
    }

    function approveMilestone(uint256 jobId, uint256 milestoneId) 
        external 
        onlyClient(jobId)
        jobNotDisputed(jobId)
        jobNotCancelled(jobId)
    {
        Job storage j = jobs[jobId];
        require(milestoneId < j.milestones.length, "Invalid milestone");
        
        Milestone storage m = j.milestones[milestoneId];
        require(m.submitted, "Not submitted");
        require(!m.released, "Already released");
        
        m.released = true;
        m.releasedAt = block.timestamp;
        j.releasedAmount += m.amount;
        
        payable(j.freelancer).transfer(m.amount);
        
        emit MilestoneApproved(jobId, milestoneId, m.amount);
    }

    function rejectMilestone(uint256 jobId, uint256 milestoneId, string calldata reason) 
        external 
        onlyClient(jobId)
        jobNotDisputed(jobId)
        jobNotCancelled(jobId)
    {
        Job storage j = jobs[jobId];
        require(milestoneId < j.milestones.length, "Invalid milestone");
        
        Milestone storage m = j.milestones[milestoneId];
        require(m.submitted, "Not submitted");
        require(!m.released, "Already released");
        
        m.submitted = false;
        m.rejected = true;
        m.submittedWork = "";
        
        emit MilestoneRejected(jobId, milestoneId, reason);
    }

    function raiseDispute(uint256 jobId) 
        external 
        jobNotCancelled(jobId)
    {
        Job storage j = jobs[jobId];
        require(msg.sender == j.client || msg.sender == j.freelancer, "Unauthorized");
        require(!j.disputed, "Already disputed");
        
        j.disputed = true;
        
        emit DisputeRaised(jobId, msg.sender);
    }

    function resolveDispute(uint256 jobId, bool clientFavored, uint256[] calldata milestonePayouts) 
        external 
    {
        // In production, this should be called by an arbiter/admin
        // For now, we'll allow either party to resolve (you should add proper access control)
        Job storage j = jobs[jobId];
        require(j.disputed, "Not disputed");
        require(milestonePayouts.length == j.milestones.length, "Invalid payouts length");
        
        uint256 totalPayout;
        for(uint i = 0; i < milestonePayouts.length; i++) {
            totalPayout += milestonePayouts[i];
        }
        
        uint256 remainingAmount = j.totalAmount - j.releasedAmount;
        require(totalPayout <= remainingAmount, "Payout exceeds remaining amount");
        
        // Distribute payouts
        if(clientFavored) {
            if(remainingAmount > totalPayout) {
                payable(j.client).transfer(remainingAmount - totalPayout);
            }
        }
        
        if(totalPayout > 0) {
            payable(j.freelancer).transfer(totalPayout);
            j.releasedAmount += totalPayout;
        }
        
        j.disputed = false;
        
        emit DisputeResolved(jobId, clientFavored);
    }

    function cancelJob(uint256 jobId) 
        external 
        onlyClient(jobId)
        jobNotDisputed(jobId)
    {
        Job storage j = jobs[jobId];
        require(!j.cancelled, "Already cancelled");
        
        // Only allow cancellation if no milestones have been submitted
        for(uint i = 0; i < j.milestones.length; i++) {
            require(!j.milestones[i].submitted, "Cannot cancel after work submitted");
        }
        
        j.cancelled = true;
        uint256 refundAmount = j.totalAmount - j.releasedAmount;
        
        if(refundAmount > 0) {
            payable(j.client).transfer(refundAmount);
        }
        
        emit JobCancelled(jobId);
    }

    function getJob(uint256 jobId) external view returns (
        address client,
        address freelancer,
        uint256 totalAmount,
        uint256 releasedAmount,
        bool disputed,
        bool cancelled,
        string memory title,
        string memory description,
        uint256 createdAt,
        uint256 milestoneCount
    ) {
        Job storage j = jobs[jobId];
        return (
            j.client,
            j.freelancer,
            j.totalAmount,
            j.releasedAmount,
            j.disputed,
            j.cancelled,
            j.title,
            j.description,
            j.createdAt,
            j.milestones.length
        );
    }

    function getMilestones(uint256 jobId) external view returns(Milestone[] memory) {
        return jobs[jobId].milestones;
    }

    function getMilestone(uint256 jobId, uint256 milestoneId) external view returns(
        uint256 amount,
        bool submitted,
        bool released,
        bool rejected,
        string memory workDescription,
        string memory submittedWork,
        uint256 submittedAt,
        uint256 releasedAt
    ) {
        require(milestoneId < jobs[jobId].milestones.length, "Invalid milestone");
        Milestone storage m = jobs[jobId].milestones[milestoneId];
        return (
            m.amount,
            m.submitted,
            m.released,
            m.rejected,
            m.workDescription,
            m.submittedWork,
            m.submittedAt,
            m.releasedAt
        );
    }

    function getJobsByParty(address party) external view returns(uint256[] memory) {
        uint256 count = 0;
        for(uint256 i = 1; i <= jobCount; i++) {
            if(jobs[i].client == party || jobs[i].freelancer == party) {
                count++;
            }
        }

        uint256[] memory jobIds = new uint256[](count);
        uint256 index = 0;
        for(uint256 i = 1; i <= jobCount; i++) {
            if(jobs[i].client == party || jobs[i].freelancer == party) {
                jobIds[index] = i;
                index++;
            }
        }

        return jobIds;
    }
}