// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SafeYieldVault - secure ETH vault with reentrancy protection
contract SafeYieldVault {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamp;
    uint256 public totalDeposited;
    uint256 public yieldRateBps = 500;
    bool private _locked;

    modifier nonReentrant() {
        require(!_locked, "Reentrancy");
        _locked = true;
        _;
        _locked = false;
    }

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount, uint256 yieldPaid);

    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Must deposit > 0");
        balances[msg.sender] += msg.value;
        depositTimestamp[msg.sender] = block.timestamp;
        totalDeposited += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function pendingYield(address user) public view returns (uint256) {
        if (balances[user] == 0) return 0;
        uint256 duration = block.timestamp - depositTimestamp[user];
        return balances[user] * yieldRateBps * duration / (365 days * 10000);
    }

    function withdraw() external nonReentrant {
        uint256 bal = balances[msg.sender];
        require(bal > 0, "No deposit");
        uint256 yield_ = pendingYield(msg.sender);

        balances[msg.sender] = 0;
        depositTimestamp[msg.sender] = 0;
        totalDeposited -= bal;

        uint256 payout = bal + yield_;
        (bool ok, ) = payable(msg.sender).call{value: payout}("");
        require(ok, "Transfer failed");
        emit Withdraw(msg.sender, bal, yield_);
    }

    receive() external payable {}
}
