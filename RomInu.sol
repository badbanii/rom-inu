
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract SafeMath {
   function onePercent(uint256 a) internal pure returns (uint256)  { return SafeMath.safeDiv(safeMul(SafeMath.ceil(a,100),100),10000); }
   function safeAdd(uint a, uint b) internal pure returns (uint c) { c = a + b;require(c >= a); }
   function safeSub(uint a, uint b) internal pure returns (uint c) { require(b <= a); c = a - b; } 
   function safeMul(uint a, uint b) internal pure returns (uint c) { c = a * b; require(a == 0 || c / a == b); } 
   function safeDiv(uint a, uint b) internal pure returns (uint c) { require(b > 0); c = a / b; }
   function ceil(uint256 a, uint256 m) internal pure returns (uint256) { uint256 c = safeAdd(a,m); uint256 d = safeSub(c,1); return safeMul(safeDiv(d,m),m);} }


contract RomInuToken is SafeMath
{
    IUniswapV2Router02 private pancakeswapRouter=IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
    address private pancakesSwapPair;    
    
    constructor(address payable communityWalletP)
    {
        _owner=msg.sender;
        communityWallet=communityWalletP;
        emit OwnershipTransferred(address(0),_owner);
        isPayingFees[address(this)]=false;
        isPayingFees[msg.sender]=false;
        isPayingFees[pancakesSwapPair]=false;
        isPayingFees[address(pancakeswapRouter)]=false;
        isPayingFees[communityWallet]=false;
        
        reflectedBalance[msg.sender]=reflectedTotalSupply;
        presaleOpen=true;
        _approve(owner(),address(pancakeswapRouter), ~uint256(0));
        pancakesSwapPair = IUniswapV2Factory(pancakeswapRouter.factory()).createPair(address(this), pancakeswapRouter.WETH());
        emit Transfer(address(0), msg.sender, totalSupply());
    }
    
    event Transfer(address indexed sender,address indexed receiver,uint256 value);
    event Approval(address indexed holder,address indexed spender,uint256 value);
    event OwnershipTransferred(address indexed currentOwner, address indexed newOwner);
    
    uint256 private reflectedTotalSupply = (~uint256(0)-(~uint256(0)%totalSupply()));
    address private _owner;
    address private burnAddress=0x0000000000000000000000000000000000000000;
    address private communityWallet;
    mapping(address => uint256) private buyingCooldown;
    mapping(address => uint256) private sellingCooldown;
    mapping(address => uint256) private timeOfFirstSell;
    mapping(address => uint256) private numberOfSells;
    mapping(address => uint256) private timeOfFirstBuy;
    mapping(address => uint256) private numberOfBuys;
    mapping(address => uint256) private reflectedBalance;
    mapping(address => uint256) private totalBalance;
    mapping(address => mapping(address => uint256)) private allowances;
    mapping(address => bool) private isPayingFees;
    bool private presaleOpen;
   
    function name() public view virtual returns(string memory) { return "Rom Inu";}
    function symbol() public view virtual returns(string memory) { return "$RONU";}
    function decimals() public view virtual returns(uint8) { return 18;}
    function totalSupply() public view virtual returns (uint256) { return 1000000000 * 10**18;}
    function closePreSale() public virtual { require ( _owner == msg.sender); presaleOpen = false;}
    function owner() public view returns (address) { return _owner;}
    function renounceOwnership() public virtual { require(_owner == msg.sender);emit OwnershipTransferred(_owner, address(0));_owner = address(0);}
    function balanceOf(address holder) public view returns (uint256) { require(reflectedBalance[holder]<=reflectedTotalSupply); return safeDiv(reflectedBalance[holder],safeDiv(reflectedTotalSupply,totalSupply()));}
    function allowance(address holder, address spender) public view returns (uint256) { return allowances[holder][spender];}
    function approve(address spender, uint256 value) public returns (bool) { _approve(msg.sender, spender, value);return true;}
    function _approve(address holder, address spender, uint256 amount) private { allowances[holder][spender] = amount; emit Approval(holder, spender, amount);}
    function transferFrom(address holder, address recipient, uint256 amount) public returns (bool) {_transfer(holder, recipient, amount);_approve(holder,msg.sender,safeSub(allowances[holder][msg.sender],amount));return true;}
    function transfer(address recipient, uint256 amount) public returns (bool) { _transfer(msg.sender, recipient, amount); return true;}
    
    function testMaxTx() public view virtual returns (uint256)
    {
        return onePercent(balanceOf(pancakesSwapPair));
    }
    
    function _transfer(address from, address to, uint256 amount) private 
    {
         require ( amount > 0 );
         address cachedOwner = _owner;
         address cachedCommunityWallet = communityWallet;
         uint256 reflectedAmount = safeMul( amount,safeDiv(reflectedTotalSupply,totalSupply() ));
         uint256 fee = 0;
         
        if(presaleOpen)
        {
            require( to == cachedOwner || from == cachedOwner );
        }
         else
         {
             if ( from != cachedOwner && to != cachedOwner && from != cachedCommunityWallet && to != cachedCommunityWallet)
             {
                 if ( from != address(pancakeswapRouter) && to != address(pancakeswapRouter) && from != address(this) && to != address(this) )
                 {
                    require( msg.sender == address(pancakeswapRouter) || msg.sender == pancakesSwapPair );
                 }
                 
                 if ( from == pancakesSwapPair && to != address(pancakeswapRouter) && isPayingFees[to] )
                 {
                      require ( reflectedAmount <= onePercent(balanceOf(pancakesSwapPair)) );
                      require(buyingCooldown[to] < block.timestamp);
                      buyingCooldown[to] = block.timestamp + (1 minutes);
                 }
                 
                 if ( from != pancakesSwapPair &&  isPayingFees[from] )
                 {
                    require ( reflectedAmount <= onePercent(balanceOf(pancakesSwapPair)) );
                 }
             }
        }

        if(fee > 0)
        {
        
           reflectedAmount = safeSub(reflectedAmount,safeMul(onePercent(reflectedAmount),fee));
           reflectedTotalSupply = safeSub(reflectedTotalSupply,safeMul(onePercent(reflectedAmount),fee));
           swapRomInu(safeMul(onePercent(reflectedAmount),fee));
        }
        
        
        reflectedBalance[from] = safeSub ( reflectedBalance[from],reflectedAmount );
        reflectedBalance[to] = safeAdd ( reflectedBalance[to],reflectedAmount );
        emit Transfer(from, to, amount);
    }
    
    function swapRomInu(uint256 value) private
    {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapRouter.WETH();
        _approve(address(this),address(pancakeswapRouter),value);
        pancakeswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(value,0,path,address(this),block.timestamp);
        
        if(address(this).balance > 0)
        {
            transfer(_owner,value);
        }
    }
}

interface IUniswapV2Factory  { function createPair(address tokenA, address tokenB) external returns (address pair); }
interface IUniswapV2Router02 { function factory() external pure returns (address); function WETH() external pure returns (address);  function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amountIn,uint256 amountOutMin,address[] calldata path,address to,uint256 deadline) external;}