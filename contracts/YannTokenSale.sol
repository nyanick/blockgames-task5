// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./YannToken.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract YannTokenSale {
    string public name = "Yann Farm";
    address public owner;
    mapping(address => uint256) public stakingBalance;
    mapping(address => bool) public hasStaked;
    mapping(address => uint256) public timeOfStakingFor;
    address[] public stakers;
    event Staked(address by, uint256 amount);
    event Withdrawn(address by, uint256 amount);

    address payable public admin;
    address payable private ethFunds =
        payable(0xFE745cab1c32EA2672a5884ED978042EBEd42A68);
    YannToken public token;
    uint256 public tokensSold;
    int256 public tokenPriceUSD;
    AggregatorV3Interface internal priceFeed;

    uint256 public transactionCount;

    event Sell(address _buyer, uint256 _amount);

    struct Transaction {
        address buyer;
        uint256 amount;
    }

    mapping(uint256 => Transaction) public transaction;

    constructor(YannToken _token) {
        priceFeed = AggregatorV3Interface(
            0x9326BFA02ADD2366b30bacB125260Af641031331
        );
        tokenPriceUSD = 5;
        token = _token;
        admin = payable(msg.sender);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the owner of the token farm can call this function"
        );
        _;
    }

    function getETHPrice() public view returns (int256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (price / 10**8);
    }

    function yannTokenPriceInETH() public view returns (int256) {
        int256 ethPrice = getETHPrice();
        return tokenPriceUSD / ethPrice;
    }

    function modifyTokenBuyPrice(uint256 _newPrice)
        public
        onlyOwner
        returns (bool)
    {
        require(
            _newPrice > 0,
            "[Optional]Exchange rate can not be set to zero"
        );
        require(
            uint256(tokenPriceUSD) == _newPrice,
            "New Exchange rate must differ from old/previous rate"
        );
        tokenPriceUSD = int256(_newPrice);
        return true;
    }

    function buyToken(uint256 _amount) public payable {
        int256 yannTokenPriceETH = yannTokenPriceInETH();
        // Check that the buyer sends the enough ETH
        require(int256(msg.value) >= yannTokenPriceETH * int256(_amount));
        // Check that the sale contract provides the enough ETH to make this transaction.
        require(token.balanceOf(address(this)) >= _amount);
        // Make the transaction inside of the require
        // transfer returns a boolean value.
        require(token.transfer(msg.sender, _amount));
        // Transfer the ETH of the buyer to us
        ethFunds.transfer(msg.value);
        // Increase the amount of tokens sold
        tokensSold += _amount;
        // Increase the amount of transactions
        transaction[transactionCount] = Transaction(msg.sender, _amount);
        transactionCount++;
        // Emit the Sell event
        emit Sell(msg.sender, _amount);
    }

    function endSale() public {
        require(msg.sender == admin);
        // Return the tokens that were left inside of the sale contract
        uint256 amount = token.balanceOf(address(this));
        require(token.transfer(admin, amount));
        selfdestruct(payable(admin));
    }

    function getStakers() public view returns (address[] memory) {
        return stakers;
    }

    //stake tokens - investor puts money into the app (deposit)
    function stakeTokens(uint256 _amount) public returns (bool) {
        require(_amount > 0, "Amount cannot be 0");
        //transfer mock dai tokens to this contract for staking

        bool res = token.transferFrom(msg.sender, address(this), _amount);

        if (!res) return false;
        //update staking balance
        stakingBalance[msg.sender] += _amount;

        //update time of staking
        timeOfStakingFor[msg.sender] = block.timestamp;

        // add user to stakers array only if they havent staked already,
        // because later we'd want to give them only once the issued tokens
        if (!hasStaked[msg.sender]) {
            stakers.push(msg.sender);
        }
        //update staking status
        hasStaked[msg.sender] = true;

        emit Staked(msg.sender, _amount);
        return true;
    }

    //unstake tokens - investor withdraws money (withdraw)
    //withdraw and arbitrary amount of tokens
    function withdrawTokens(uint256 _amount) public returns (bool) {
        require(_amount > 0, "Amount cannot be 0");
        require(
            _amount <= stakingBalance[msg.sender],
            "Cannot withdraw more than you have in your staking balance"
        );
        require(
            hasStaked[msg.sender],
            "Caller must have staked in order to withdraw something"
        );
        //allow them to withdraw a week after their latest stake
        require(
            block.timestamp >= (timeOfStakingFor[msg.sender] + 7 days),
            "The block timestamp should be at least 7 day after the time of staking"
        );

        //transfer 1% of the withdrawn amount for stacking
        bool res = token.transfer(msg.sender, (_amount + (_amount * 1) / 100));
        if (!res) return false;
        //update staking balance
        stakingBalance[msg.sender] -= _amount;

        //if account has withdrawn everything we need to remove them from the stakers array
        if (stakingBalance[msg.sender] == 0) {
            address[] storage arr = stakers;
            for (uint256 i = 0; i < arr.length; i++) {
                if (arr[i] == msg.sender) {
                    arr[i] = arr[arr.length - 1];
                    arr.pop();
                    //update staking status
                    hasStaked[msg.sender] = false;
                    break;
                }
            }
        }
        emit Withdrawn(msg.sender, _amount);
        return true;
    }
}
