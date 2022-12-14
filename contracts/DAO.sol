// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

contract DAO {
    struct Proposal {
        uint256 id;
        string name;
        uint256 amount;
        address payable recipient;
        uint256 votes;
        uint256 end;
        bool executed;
    }
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public investors;
    mapping(address => uint256) public shares;
    mapping(address => mapping(uint256 => bool)) public votes;
    uint256 public nextProposalId;
    uint256 public voteTime;
    uint256 public quorum;
    address public admin;
    uint256 public totalShares;
    uint256 public availableFunds;
    uint256 public contributionEnd;

    constructor(
        uint256 contributionTime,
        uint256 _voteTime,
        uint256 _quorum
    ) {
        contributionEnd = block.timestamp + contributionTime;
        voteTime = _voteTime;
        quorum = _quorum;
        admin = msg.sender;
    }

    function contribute() external payable {
        require(
            block.timestamp < contributionEnd,
            "cannot contribute after contibutionEnd"
        );
        investors[msg.sender] = true;
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
        availableFunds += msg.value;
    }

    function redeemShare(uint256 amount) external {
        require(shares[msg.sender] >= amount, "not enough shares");
        require(availableFunds >= amount, "not enough availableFund");
        shares[msg.sender] -= amount;
        availableFunds -= amount;
        msg.sender.call{value: amount};
    }

    function transferShare(uint256 amount, address to) external {
        require(shares[msg.sender] >= amount, "not enough shares");
        shares[msg.sender] -= amount;
        shares[to] += amount;
        investors[to] = true;
    }

    function createProposal(
        string memory name,
        uint256 amount,
        address payable recepient
    ) external {
        require(availableFunds >= amount, "amount too big");
        proposals[nextProposalId] = Proposal(
            nextProposalId,
            name,
            amount,
            recepient,
            0,
            block.timestamp + voteTime,
            false
        );
        availableFunds -= amount;
        nextProposalId++;
    }

    function vote(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(
            votes[msg.sender][proposalId] == false,
            "voters can only vote once for a proposal"
        );
        require(
            block.timestamp < proposal.end,
            "can only vote until proposal end"
        );
        votes[msg.sender][proposalId] = true;
        proposal.votes += shares[msg.sender];
    }

    function executeProposal(uint256 proposalId) external onlyAdmin {
        Proposal storage proposal = proposals[proposalId];
        require(
            block.timestamp >= proposal.end,
            "can not execute a proposal before end date"
        );
        require(
            proposal.executed == false,
            "can not executed a proposal that is alreday executed"
        );
        require(
            (proposal.votes / totalShares) * 100 >= quorum,
            "cannot executed a proposal with below quorum"
        );
        _transferEther(proposal.amount, proposal.recipient);
    }

    function withdrawEther(uint256 amount, address payable to)
        external
        onlyAdmin
    {
        _transferEther(amount, to);
    }

    receive() external payable {
        availableFunds += msg.value;
    }

    function _transferEther(uint256 amount, address payable to) internal {
        require(amount <= availableFunds, "not enough availableFund");
        availableFunds -= amount;
        to.transfer(amount);
    }

    modifier onlyInvestors() {
        require(investors[msg.sender] == true, "only investors");
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }
}
