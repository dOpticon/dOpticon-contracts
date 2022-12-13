pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract dOpticonBorrower is ERC20, ERC20Burnable {
    using Math for uint256;
    uint256 public totalBorrowed;
    uint256 public lastAction;
    IERC20 public token;
    uint256 internal ONE_YEAR = 365 days;

    modifier update(uint256 value) {
        if (block.timestamp > lastAction) {
            uint256 interest = pendingInterest(value);
            totalBorrowed += interest;
            lastAction = block.timestamp;
        }
        _;
    }

    modifier transferToken(uint256 amount) {
        token.transferFrom(msg.sender, address(this), amount);
        _;
    }

    constructor() ERC20("dOpticon ETH Interest Bearing", "dpETH") {
        token = IERC20(0x8d4243b9C4Ba43dB84D6CcA3035DEbb370e288e5);
        lastAction = block.timestamp;
    }

    function getBorrowAPR(uint256 debt, uint256 total)
        internal
        pure
        returns (uint256)
    {
        if (total == 0) {
            return 0;
        }
        uint256 utilization = getUtilization(debt, total);
        uint256 sqrt = 1e18 - (1e36 - utilization**2).sqrt();
        return (sqrt * 3) / 2;
    }

    function getUtilization(uint256 debt, uint256 total)
        internal
        pure
        returns (uint256)
    {
        if (total == 0) {
            return 0;
        }
        return ((debt * 1e18) / total);
    }

    function deposit(uint256 amount)
        public
        transferToken(amount)
        update(amount)
    {
        _mint(
            msg.sender,
            (totalToken() - amount) == 0
                ? amount
                : (amount * totalSupply()) / (totalToken() - amount)
        );
    }

    function withdraw(uint256 amount) public update(0) {
        uint256 tokenAmount = (amount * totalToken()) / totalSupply();
        _burn(msg.sender, amount);
        token.transfer(msg.sender, tokenAmount);
    }

    function borrow(uint256 amount) public update(0) {
        token.transfer(msg.sender, amount);
        totalBorrowed += amount;
    }

    function totalToken() public view returns (uint256) {
        return token.balanceOf(address(this)) + totalBorrowed;
    }

    function pendingInterest(uint256 value) public view returns (uint256) {
        if (block.timestamp > lastAction) {
            uint256 timePast = block.timestamp - lastAction;
            uint256 balance = token.balanceOf(address(this)) - value;
            return
                ((getBorrowAPR(totalBorrowed, balance) / ONE_YEAR) *
                    timePast *
                    totalBorrowed) / 1e18;
        }
    }
}
