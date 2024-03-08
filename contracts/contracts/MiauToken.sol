// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MiauToken is ERC20, ERC20Votes,Ownable, ReentrancyGuard  {


    address public miauDAO;
    uint256 public vestingStartTime;
    uint256 public constant vestingDuration = 3 * 365 days;
    uint256 public constant totalVestingAmount = 800e6 * 1e18; // 800 million tokens, assuming 18 decimals
    uint256 public totalClaimed;
    uint256 private constant MAX_SUPPLY = 1e9 * 1e18; // 1 billion tokens
    uint256 public  feeRate  = 100;

    event MiauDAOSetAddress(address indexed miauDAO);
    event DAOClaimed(uint256 amount);
    event FeeRateUpdated(uint256 newFeeRate);
    event MiauSpotted(string url);


    constructor() ERC20("Miau", "Miau") ERC20Permit("Miau") {
        
    }



    function setMiauDAO(address _miauDAO) external onlyOwner {
        require(_miauDAO != address(0), "MiauDAO address cannot be the zero address");
        miauDAO = _miauDAO;

        // Transfer ownership of the token contract to the MiauDAO
        transferOwnership(miauDAO);

        // Mint 200M tokens to the MiauDAO
        uint256 daoTokens = 200e6 * 1e18; // Adjust based on your token's decimals
        _mint(miauDAO, daoTokens);
        setVestingStartTime();
        emit MiauDAOSetAddress(_miauDAO);
    }

    function setFeeRate(uint256 _feeRate) external onlyOwner {
        feeRate = _feeRate;
        emit FeeRateUpdated(_feeRate);
    }

    function miauSpotted(string memory url) external {
        require(balanceOf(msg.sender) > 20000 * 1e18, "Caller must own more than 20,000 Miau tokens"); // Assuming token has 18 decimals
        emit MiauSpotted(url);
    }


    function calculateVestedAmount() public view returns (uint256) {
        if (block.timestamp < vestingStartTime) return 0;
        uint256 timeElapsed = block.timestamp - vestingStartTime;
        if (timeElapsed >= vestingDuration) {
            return totalVestingAmount;
        } else {
            return (totalVestingAmount * timeElapsed) / vestingDuration;
        }
    }


    function DAOClaim() external {
        require(msg.sender == miauDAO, "Only MiauDAO can claim");
        uint256 vestedAmount = calculateVestedAmount();
        uint256 claimable = vestedAmount - totalClaimed;
        require(claimable > 0, "No tokens available for claim");
        totalClaimed += claimable;
        _mint(miauDAO, claimable);
        emit DAOClaimed(claimable);
    }

    function setVestingStartTime() internal {
    vestingStartTime = block.timestamp;
}


    function _transfer(address sender, address recipient, uint256 amount) internal override nonReentrant {
        uint256 fee = (amount * feeRate) / 100000; // Calculate the 0.1% fee
    uint256 totalAmount = amount + fee; // Calculate total amount to be deducted from sender
    
    // Check if sender's balance can cover the amount plus the fee
    if (balanceOf(sender) >= totalAmount) {
        super._transfer(sender, miauDAO, fee); // Transfer the fee to miauDAO
        super._transfer(sender, recipient, amount); // Then transfer the original amount to the recipient
    } else {
        super._transfer(sender, recipient, amount); // If not, transfer without applying the fee
    }
    }

    // Override required due to Solidity multiple inheritance.
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    // Override required due to Solidity multiple inheritance.
    function _mint(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply exceeded");
        super._mint(account, amount);
    }

    // Override required due to Solidity multiple inheritance.
    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
