// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract DAO {
    struct Proposal {
        uint256 id;
        string name;
        uint256 amount;
        address payable recipient;
        uint256 votes;
        uint256 timeEnd;
        bool executed;
    }

    mapping(address => bool) public investors;
    mapping(address => uint256) public shares;
    mapping(uint256 => Proposal) proposals;
    mapping(address => mapping(uint256 => bool)) public votes;

    uint256 public totalShares;
    uint256 public availableFunds;
    uint256 public contributionEnd;
    uint256 public nextProposalId;
    uint256 public voteTime;
    uint256 public quorum;
    address public admin;

    constructor(
        uint256 contributionTime,
        uint256 _voteTime,
        uint256 _quorum
    ) public {
        require(
            _quorum > 0 && _quorum < 100,
            "quorum must be between 0 and 100"
        );
        contributionEnd = block.timestamp + contributionTime;
        voteTime = _voteTime;
        quorum = _quorum;
        admin = msg.sender;
    }

    function contribute() external payable {
        require(
            block.timestamp < contributionEnd,
            "cannot contribute contribution ends"
        );
        investors[msg.sender] = true;
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
        availableFunds += msg.value;
    }

    function redeemShare(uint256 amount) external {
        require(shares[msg.sender] >= amount, "not enough shares");
        require(availableFunds >= amount, "Not enough available fund");
        shares[msg.sender] -= amount;
        availableFunds -= amount;
        msg.sender.transfer(amount);
    }

    function transferShare(uint256 amount, address to) external {
        require(shares[msg.sender] >= amount, "not enough shares");
        shares[msg.sender] -= amount;
        shares[to] -= amount;
        investors[to] = true;
    }

    function createProposal(
        string memory name,
        uint256 amount,
        address payable recipient
    ) external onlyInvestors() {
        require(availableFunds >= amount, "amount too big");
        proposals[nextProposalId] = Proposal(
            nextProposalId,
            name,
            amount,
            recipient,
            0,
            block.timestamp + voteTime,
            false
        );
        availableFunds -= amount;
        nextProposalId++;
    }

    function vote(uint256 proposalId) external onlyInvestors() {
        Proposal storage proposal = proposals[proposalId];
        require(
            votes[msg.sender][proposalId] == false,
            "investor can only vote for a proposal"
        );
        require(
            block.timestamp < proposal.timeEnd,
            "can only vote until proposal end"
        );
        votes[msg.sender][proposalId] = true;
        proposal.votes += shares[msg.sender];
    }

    function execute(uint256 proposalId) external onlyAdmin() {
        Proposal storage proposal = proposals[proposalId];
        require(
            block.timestamp >= proposal.timeEnd,
            "cannot execute a proposal before time end "
        );
        require(proposal.executed == false, "cannot execute a proposal");
        require(
            (proposal.votes / totalShares) * 100 >= quorum,
            "cannot execute proposal with votes below quorum"
        );
        _transferEther(proposal.amount, proposal.recipient);
    }

    function withdrawEther(uint256 amount, address payable to) external {
        _transferEther(amount, to);
    }

    fallback() external payable {
        availableFunds += msg.value;
    }

    receive() external payable {}

    function _transferEther(uint256 amount, address payable to)
        internal
        onlyAdmin()
    {
        require(amount <= availableFunds, "not enough available fund");
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
