// SPDX-License-Identifier: MIT
pragma solidity ^0.6.7;

import "../strategy-joe-rush-farm-base.sol";

///@notice Trader Joe's AVAX/PTP liquidity pool strategy with JOE and PTP rewards
contract StrategyJoeAvaxPtp is StrategyJoeRushFarmBase {
    // Token and contract addresses
    uint256 public lp_poolId = 28;

    address public joe_avax_ptp_lp = 0xCDFD91eEa657cc2701117fe9711C9a4F61FEED23;
    address public ptp = 0x22d4002028f537599bE9f666d1c4Fa138522f9c8;


    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        public
        StrategyJoeRushFarmBase(
            lp_poolId,
            joe_avax_ptp_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** State Mutations ****
    ///@notice Swap rewards to WAVAX, take fee, then swap half WAVAX for PTP and add liquidity 
    function harvest() public override onlyBenevolent {
        // Collects Joe tokens
        IMasterChefJoeV2(masterChefJoeV3).deposit(poolId, 0);

        // Take AVAX Rewards    
        uint256 _avax = address(this).balance;              // get balance of native AVAX
        if (_avax > 0) {                                    // wrap AVAX into ERC20
            WAVAX(wavax).deposit{value: _avax}();
        }
        
        uint256 _ptp = IERC20(ptp).balanceOf(address(this));     // get balance of PTP Tokens
         if (_ptp > 0) {
            _swapTraderJoe(ptp, wavax, _ptp);
        }

        uint256 _joe = IERC20(joe).balanceOf(address(this));    // get balance of JOE Tokens
        if (_joe > 0) {
            _swapTraderJoe(joe, wavax, _joe);
        }

        // Get balance of WAVAX, take fee, swap half WAVAX for PTP
        uint256 _wavax = IERC20(wavax).balanceOf(address(this));  
        if (_wavax > 0) {
            uint256 _keep = _wavax.mul(keep).div(keepMax);
            if (_keep > 0){
                _takeFeeWavaxToSnob(_keep);
            }

            _wavax = IERC20(wavax).balanceOf(address(this));
            _swapTraderJoe(wavax, ptp, _wavax.div(2));
        }

        // Add liquidity for AVAX/PTP
        _wavax = IERC20(wavax).balanceOf(address(this));
        _ptp = IERC20(ptp).balanceOf(address(this));
        if (_wavax > 0 && _ptp > 0) {
            IERC20(wavax).safeApprove(joeRouter, 0);
            IERC20(wavax).safeApprove(joeRouter, _wavax);

            IERC20(ptp).safeApprove(joeRouter, 0);
            IERC20(ptp).safeApprove(joeRouter, _ptp);

            IJoeRouter(joeRouter).addLiquidity(
                wavax,
                ptp,
                _wavax,
                _ptp,
                0,
                0,
                address(this),
                now + 60
            );

            // Donates DUST
            _wavax = IERC20(wavax).balanceOf(address(this));
            _ptp = IERC20(ptp).balanceOf(address(this));
            _joe = IERC20(joe).balanceOf(address(this));
            if (_wavax > 0){
                IERC20(wavax).transfer(
                    IController(controller).treasury(),
                    _wavax
                );
            }
            
            if (_ptp > 0){
                IERC20(ptp).safeTransfer(
                    IController(controller).treasury(),
                    _ptp
                );
            }  
            if (_joe > 0){
                IERC20(joe).safeTransfer(
                    IController(controller).treasury(),
                    _joe
                );
            }  
        }
        _distributePerformanceFeesAndDeposit();
    }

    // **** Views ****
    ///@notice Return the strategy name
    function getName() external override pure returns (string memory) {
        return "StrategyJoeAvaxPtp";
    }
}