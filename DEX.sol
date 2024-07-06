// SPDX-License-Identifier: GPL-3.0-or-later
// Lance Tecson lat4nyv

pragma solidity ^0.8.21;

import "./IDEX.sol";
import "./IERC20.sol";
import "./TokenCC.sol";
//import "./EtherPriceOracleConstant.sol";

contract DEX is IDEX{
    constructor(){
    deployer = msg.sender;
    }

    address public deployer;

    function decimals() public view override returns (uint){
        return TokenCC(ERC20Address).decimals();
    } 

    function symbol() public view override returns (string memory){
        return TokenCC(ERC20Address).symbol();
    }  
    function getEtherPrice() public view override returns (uint){
        return IEtherPriceOracle(etherPricer).price();
    }
    
    function getTokenPrice() public view override returns (uint){
        return IEtherPriceOracle(etherPricer).price() * x / y * 10 ** decimals() / 10 ** 18;
    }

    uint public override k;  // invarient
    uint public override x;  // ether amount
    uint public override y;  // token amount
    function getPoolLiquidityInUSDCents() public view override returns (uint){
        return 2 * getEtherPrice() * x;
    }
    mapping (address => uint) public override etherLiquidityForAddress;
    mapping (address => uint) public override tokenLiquidityForAddress;

    function createPool(uint _tokenAmount, uint _feeNumerator, uint _feeDenominator, address _erc20token, address _etherPricer) public payable{
        require(k == 0, "Already called!");
        require(msg.sender == deployer, "Only deployer can call!");
        require(msg.value > 0, "Obey Newton's law of motion!");

        adjustingLiquidity = true;
        x = msg.value;
        y = _tokenAmount;
        k = x * y;
        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;
        ERC20Address = _erc20token;
        etherPricer = _etherPricer;
        IERC20(ERC20Address).transferFrom(msg.sender, address(this), y);
        adjustingLiquidity = false;
        emit liquidityChangeEvent();
    }

    uint public override feeNumerator;
    uint public override feeDenominator;
    uint public override feesEther;
    uint public override feesToken;

    address public override etherPricer;
    address public override ERC20Address;

    function addLiquidity() public payable{
        uint ratio = y / x;
        require(msg.value * ratio <= ERC20(ERC20Address).balanceOf(ERC20Address));

        adjustingLiquidity = true;
        // TokenCC(ERC20Address).approve(address(this), msg.value * ratio);
        uint val = msg.value * y / x;
        x += msg.value;
        y += val;//msg.value * ratio;
        k = x * y;
        etherLiquidityForAddress[msg.sender] += msg.value;
        tokenLiquidityForAddress[msg.sender] += val;
        ERC20(ERC20Address).transferFrom(msg.sender , address(this), val);//msg.value * ratio);
        adjustingLiquidity = false;
        emit liquidityChangeEvent();
    }
    function removeLiquidity(uint amountEther) public{
        require(amountEther < x, "Too much ether removed!");
        uint ratio = y / x;
        require(amountEther * ratio <= ERC20(ERC20Address).balanceOf(address(this)));
        (bool success, ) = payable(msg.sender).call{value: amountEther}("");
        require(success, "Failed to transfer ETH");
        
        adjustingLiquidity = true;
        uint val = amountEther * y / x;
        x -= amountEther;
        y -= val;
        k = x * y;
        etherLiquidityForAddress[msg.sender] -= amountEther;
        tokenLiquidityForAddress[msg.sender] -= val;
        ERC20(ERC20Address).transferFrom(address(this) , msg.sender, val);
        adjustingLiquidity = false;
        emit liquidityChangeEvent();
    }

    receive() external override payable{
        // ether2token

        x += msg.value;
        uint payout = y - k  / x;
        y -= payout;
        uint fee = payout * feeNumerator / feeDenominator;
        feesToken += fee;
        ERC20(ERC20Address).transfer(msg.sender, payout - fee);
        emit liquidityChangeEvent();
    }

    bool public adjustingLiquidity;

    function onERC20Received(address from, uint amount, address erc20) public returns (bool){
        require(erc20 == ERC20Address, "Wrong token contract!");
        //require(!adjustingLiquidity);  // token2ether

        if (!adjustingLiquidity){
            y += amount;
            uint payout = x - k  / y;
            x -= payout;
            uint fee = payout * feeNumerator / feeDenominator;
            feesEther += fee;
            (bool success, ) = payable(from).call{value: payout - fee}("");
            require(success, "Failed to transfer ETH");
            emit liquidityChangeEvent();
        }
        return true;
    }


    function setEtherPricer(address p) public{
        etherPricer = p;
    }


    function getDEXinfo() external view returns (address, string memory, string memory, address, uint, uint, uint, uint, uint, uint, uint, uint){
        return (address(this), symbol(), TokenCC(ERC20Address).name(), address(ERC20Address), k, x, y, feeNumerator, feeDenominator, decimals(), feesEther, feesToken);
    }

    function reset() public pure{
        require(false);
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IDEX).interfaceId || interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC20Receiver).interfaceId;
    }
}