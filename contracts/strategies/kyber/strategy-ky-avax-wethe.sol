// SPDX-License-Identifier: MIT	
pragma solidity ^0.6.7;

import "../bases/strategy-kyber-farm-base.sol";

/// @notice This is the strategy contract for Kyber's AVAX-WETHE pair with KNC and AVAX rewards
contract StrategyKyAvaxWethE is StrategyKyberFarm {
    address public constant avax_wethe = 0x2ea96d68413260ED6fEC252536B03a5fC0E9A849;
    address public constant avax_wethe_gauge = 0x845d1D0D9b344fbA8a205461B9E94aEfe258B918;

    address public constant wethe = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;

    uint256 public avax_wethe_poolId = 2; 
    uint256 public index; 

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
    public 
    StrategyKyberFarm(
        avax_wethe_gauge,
        avax_wethe_poolId,
        avax_wethe, 
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
        IKyber(avax_wethe_gauge).harvest(avax_wethe_poolId);

        // Retrieve reward from the vesting contract and increases index for the next reward 
        uint256[] memory indices = new uint256[](1);
        indices[0] = index;
        IRewardLocker(vesting).vestScheduleAtIndices(knc, indices);
        index = index + 1; 

        // Wrapping AVAX into WAVAX  
        uint256 _avax = address(this).balance;                        // get balance of native Avax
        if (_avax > 0) {                                              // wrap avax into ERC20
            WAVAX(wavax).deposit{value: _avax}();
        }

        // Swapping all the knc rewards for wavax 
        uint256 _knc = IERC20(knc).balanceOf(address(this));          // get the balance of KNC tokens
        if (_knc > 0) {
            _swapToken(knc, wavax, _knc);
        }
        
        // Swapping half the Wavax for WETHE
        uint256 _wavax = IERC20(wavax).balanceOf(address(this));      // get the balance of WAVAX tokens
        if (_wavax > 0) {
            uint256 _keep = _wavax.mul(keep).div(keepMax);
            if (_keep > 0) {
               _takeFeeWavaxToSnob(_keep);
            }

            _wavax = IERC20(wavax).balanceOf(address(this));
            _swapTraderJoe(wavax, wethe, _wavax.div(2));              
        }

        // Adds liquidity for the AVAX-WETHE pair
        uint256 _wethe = IERC20(wethe).balanceOf(address(this));
        _wavax = IERC20(wavax).balanceOf(address(this));

        IERC20(wethe).safeApprove(kyberRouter, 0); 
        IERC20(wethe).safeApprove(kyberRouter, _wethe); 

        IERC20(wavax).safeApprove(kyberRouter, 0); 
        IERC20(wavax).safeApprove(kyberRouter, _wavax); 

        ( , ,uint256 vReserve0, uint256 vReserve1, ) = IKyber(avax_wethe).getTradeInfo();
        uint256 currentRate = (vReserve1 * Q112).div(vReserve0); 

        uint256[] memory ratioBound = new uint256[](2);
        ratioBound[0] = currentRate.mul(99).div(100);
        ratioBound[1] = currentRate.mul(101).div(100);
       
        IKyber(kyberRouter).addLiquidity(
            wethe, 
            wavax, 
            avax_wethe,
            _wethe,
            _wavax,
            0,
            0,
            [ratioBound[0], ratioBound[1]],
            address(this),
            now + 60
        );

        // Donates DUST
        _wavax = IERC20(wavax).balanceOf(address(this));
        _knc= IERC20(knc).balanceOf(address(this));
        _wethe = IERC20(wethe).balanceOf(address(this));        
        if (_wavax > 0){
            IERC20(wavax).transfer(
                IController(controller).treasury(),
                _wavax
            );
        }      

        if (_knc > 0){
            IERC20(knc).transfer(
                IController(controller).treasury(),
                _knc
            );
        }     

        if (_wethe > 0){
            IERC20(wethe).transfer(
                IController(controller).treasury(),
                _wethe
            );
        }   
        _distributePerformanceFeesAndDeposit();  
    }

    // **** Views ****
    function getName() external pure override returns (string memory) {
        return "StrategyKyAvaxWethE";
    }
}