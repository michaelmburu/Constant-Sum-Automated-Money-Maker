// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "./IERC20.sol";

/*
    Constant Sum Automated Money Maker Algorithm
*/

contract CASMM {
    
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    //Keep track of the balance of the tokens locked in the contract
    uint public reserveTokenA;
    uint public reserveTokenB;

    // Keep track of total shares & shares per user
    uint public totalSupply;
    mapping(address => uint) public balanceOf;

    //Initialize
    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    //Mint shares
    function _mint(address _to, uint _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    //Burn shares
    function _burn(address _from, uint _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    //Internal function to update token reserves
    function _update(uint _reserverTokenA, uint _reserveTokenB) private {
        reserveTokenA = _reserverTokenA;
        reserveTokenB = _reserveTokenB;
    }

    //Change one token to another token
    function swap(address _tokenIn, uint _amountIn) external returns (uint amountOut) {
        //Require tokenIn is either tokenA or tokenB
        require(_tokenIn == address(tokenA) || _tokenIn == address(tokenB),  "invalid token");

        //Check if tokenIn is TokenA
        bool isTokenA = _tokenIn == address(tokenA);
        (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) = isTokenA ? (tokenA, tokenB, reserveTokenA, reserveTokenB) : (tokenB, tokenA, reserveTokenB, reserveTokenA);

        //1. Transfer token in
        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        //amountIn is difference of balance of tokens in address - reserveTokenA
        uint amountIn = tokenIn.balanceOf(address(this)) - reserveIn;

        //2. Calculate amount out (including fees)
        //dx = dy (amount of tokens In equals amount of tokens taken out
        // Trading fee = 0.3% fee, (amount out os 99.7%) 
        amountOut = (amountIn * 997) / 1000;

        //3. Update reserveTokenA and reserveTokenB
        (uint resTokenA, uint resTokenB) = isTokenA 
        ? (reserveIn + _amountIn, reserveOut - amountOut)
        : (reserveOut - amountOut, reserveIn + _amountIn);

        _update(resTokenA, resTokenB);

        //4. Transfer token out
        tokenOut.transfer(msg.sender, amountOut);
    }

    //Add tokens to AMM
    function addLiquidity(uint _amountTokenA, uint _amountTokenB) external returns (uint shares) {
        tokenA.transferFrom(msg.sender, address(this), _amountTokenA);
        tokenB.transferFrom(msg.sender, address(this), _amountTokenB);

        uint balanceTokenA = tokenA.balanceOf(address(this));
        uint balanceTokenB = tokenB.balanceOf(address(this));
        
        uint returnedTokenA = balanceTokenA - reserveTokenA;
        uint returnedTokenB = balanceTokenB - reserveTokenB;

        /*
            a = amountIn
            L = total Liquidity
            s = shares To Mint
            T = total Supply

            (L + a) / L = (T + s) / T;
            s = a * T / L
        */

        //Get total shares
        if(totalSupply == 0) {
            shares = returnedTokenA + returnedTokenB;
        }
        else{
            shares = ((returnedTokenA + returnedTokenB) * totalSupply) / (reserveTokenA + reserveTokenB);
        }

        require(shares > 0, "shares equal 0");
        _mint(msg.sender, shares);

        _update(balanceTokenA, balanceTokenB);
    }

    function removeLiquidity(uint _shares) external returns (uint returnTokenA, uint returnTokenB) {
        /*
            a = amount out
            L = total Liquidity
            s = shares
            T = total Supply

            a / L = s / T
                = (reserverTokenA + reserveTokenB) * s / T

        */

        returnTokenA = (reserveTokenA * _shares) / totalSupply;
        returnTokenB = (reserveTokenB * _shares) / totalSupply;

        _burn(msg.sender, _shares);
        _update(reserveTokenA - returnTokenA, reserveTokenB - returnTokenB);

        if(returnTokenA > 0){
            tokenA.transfer(msg.sender, returnTokenA);
        }

         if(returnTokenB > 0){
            tokenB.transfer(msg.sender, returnTokenB);
        }
    }
 }