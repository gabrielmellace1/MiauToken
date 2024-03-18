// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {MiauToken} from "./MiauToken.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint) external;
}


contract MiauDAO is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction, ReentrancyGuard
{
    MiauToken public miau;
    uint256 minSupply;
    IWETH public constant weth = IWETH(0x4300000000000000000000000000000000000004);
    uint256 public totalEthReceived = 0;
    uint256 public constant RATE = 10e6; // Miau tokens per ETH, assuming 18 decimals for MiauToken
    uint256 public constant MAX_ETH = 10 ether;
    uint256 public tokensLeftForMining;

    constructor(
        MiauToken _miau,
        uint256 _minSupply
    )
        Governor("MiauToken DAO")
        GovernorSettings(43200 /* 1 day */, 302400 /* 1 week */, 1)
        GovernorVotes(_miau)
        GovernorVotesQuorumFraction(100)
    {

        tokensLeftForMining = 200e6 * 1e18;
        miau = _miau;
        minSupply = _minSupply;
    }

    function exchangeWETHForMiauTokens(uint256 wethAmount) external nonReentrant {
        require(totalEthReceived + wethAmount <= MAX_ETH, "Exchange limit exceeded");
        uint256 miauAmount = wethAmount * RATE;
        require(weth.transferFrom(msg.sender, address(this), wethAmount), "WETH transfer failed");
        require(miau.transfer(msg.sender, miauAmount), "MiauToken transfer failed");

        totalEthReceived += wethAmount;
        tokensLeftForMining -= miauAmount;
    }




    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        require(
            miau.totalSupply() >= minSupply,
            "Proposals are disabled until the amount of tokens reaches the threshold for governance to be enabled"
        );
        return super.propose(targets, values, calldatas, description);
    }

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(
        uint256 timestamp
    )
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(timestamp);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
}
