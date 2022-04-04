// SPDX-License-Identifier: MIT	
pragma solidity ^0.6.7;

import "../bases/strategy-kyber-farm-base.sol";

/// @notice This is the strategy contract for Kyber's SAVAX-KNC pair with KNC rewards
contract StrategyKySavaxKnc is StrategyKyberFarm {
    address public constant savax_knc = 0x6778d979E3B77310Cfb2ac753fb5B47C97Cba47A;
    address public constant savax = 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE;
    address public constant savax_knc_gauge = 0x89929Bc485cE72D2Af7b7283B40b921e9F4f80b3; 

    uint256 public savax_knc_poolId = 0; 
    uint256 public index; 

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
    public 
    StrategyKyberFarm(
        savax_knc_gauge,
        savax_knc_poolId,
        savax_knc, 
        _governance, 
        _strategist, 
        _controller, 
        _timelock
    )
    {
        index = 0; 
    } 
    
    // ***** Collects Rewards and Restakes ****** // 
    function harvest() public override onlyBenevolent {
        // Harvests the rewards from the specific pool on kyber finance 
        IKyber(savax_knc_gauge).harvest(savax_knc_poolId);

        // retrieve reward from the vesting contract and increases index for the next reward 
        uint256[] memory indices = new uint256[](1);
        indices[0] = index;
        IRewardLocker(vesting).vestScheduleAtIndices(knc, indices);
        index = index + 1; 
        
        // Wrapping AVAX into WAVAX    
        uint256 _avax = address(this).balance;                     // get balance of native Avax
        if (_avax > 0) {                                           // wrap avax into ERC20
            WAVAX(wavax).deposit{value: _avax}();
        }

        uint256 _knc = IERC20(knc).balanceOf(address(this));       // get the balance of KNC tokens 

        // Swapping all the knc rewards for wavax 
        if (_knc > 0) {
            _swapToken(knc, wavax, _knc);
        }
        
        // Swapping half the Wavax for KNC, and the other half for SAVAX
        uint256 _wavax = IERC20(wavax).balanceOf(address(this));
        if (_wavax > 0) {
            uint256 _keep = _wavax.mul(keep).div(keepMax);
            if (_keep > 0) {
                _takeFeeWavaxToSnob(_keep);
            }

            _wavax = IERC20(wavax).balanceOf(address(this));
            _swapTraderJoe(wavax, savax, _wavax.div(2)); 
            _swapToken(wavax, knc, _wavax.div(2));
        }

        // Adds liquidity for the SAVAX-KNC pair
        uint256 _savax = IERC20(savax).balanceOf(address(this));
        _knc = IERC20(knc).balanceOf(address(this));

        IERC20(savax).safeApprove(kyberRouter, 0); 
        IERC20(savax).safeApprove(kyberRouter, _savax); 

        IERC20(knc).safeApprove(kyberRouter, 0); 
        IERC20(knc).safeApprove(kyberRouter, _knc); 

        ( , ,uint256 vReserve0, uint256 vReserve1, ) = IKyber(savax_knc).getTradeInfo();
        uint256 currentRate = (vReserve1 * Q112).div(vReserve0); 

        uint256[] memory ratioBound = new uint256[](2);
        ratioBound[0] = currentRate.mul(99).div(100);
        ratioBound[1] = currentRate.mul(101).div(100);

        IKyber(kyberRouter).addLiquidity(
            savax, 
            knc, 
            savax_knc,
            _savax,
            _knc,
            0,
            0,
            [ratioBound[0], ratioBound[1]],
            address(this),
            now + 60
        );

        // Donates DUST
        _wavax = IERC20(wavax).balanceOf(address(this));
        _savax = IERC20(savax).balanceOf(address(this));  
        _knc = IERC20(knc).balanceOf(address(this));    
        if (_wavax > 0){
            IERC20(wavax).transfer(
                IController(controller).treasury(),
                _wavax
            );
        }      

        if (_savax > 0){
            IERC20(savax).transfer(
                IController(controller).treasury(),
                _savax
            );
        }   

        if (_knc > 0){
            IERC20(knc).transfer(
                IController(controller).treasury(),
                _knc
            );
        }    
        _distributePerformanceFeesAndDeposit();
    }

    // **** Views ****
    function getName() external pure override returns (string memory) {
        return "StrategyKySavaxKnc";
    }
}