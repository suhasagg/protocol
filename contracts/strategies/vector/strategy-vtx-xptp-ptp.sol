// SPDX-License-Identifier: MIT
pragma solidity ^0.6.7;
import "../bases/strategy-vtx-farm-base-lp.sol";

///@notice Vector's PTP/xPTP liquidity pool strategy with VTX rewards
contract StrategyVtxPtpxPtp is StrategyVtxLPFarmBase{
    // Token and contract addresses
    address public xptp_ptp = 0xC4B7121b4FC065dECd26C33FB32e42C543E8850d;
    address public xptp_ptp_staking = 0x423D0FE33031aA4456a17b150804aA57fc157d97; 

    address public xptp = 0x060556209E507d30f2167a101bFC6D256Ed2f3e1;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
    public StrategyVtxLPFarmBase( 
        xptp_ptp_staking,
        xptp_ptp,
        _governance,
        _strategist,
        _controller,
        _timelock
    )
    {}

    // **** State Mutations ****
    ///@notice Swap rewards to PTP, take fee, then swap half PTP for xPTP and add liquidity 
    function harvest() public override onlyBenevolent {
        // Collects Reward tokens
        IMasterChefVTX(xptp_ptp_staking).deposit(xptp_ptp, 0);

        // Take AVAX Rewards    
        uint256 _avax = address(this).balance;                   // get balance of native Avax
        if (_avax > 0) {                                         // wrap avax into ERC20
            WAVAX(wavax).deposit{value: _avax}();
        }

        uint256 _vtx = IERC20(vtx).balanceOf(address(this));      // get balance of VTX Tokens
        uint256 _wavax = IERC20(wavax).balanceOf(address(this));  // get balance of AVAX Tokens
        
        // In the case of VTX Rewards, swap half for VTX for xPTP and half for PTP 
        if (_vtx > 0) {   
            _swapTraderJoe(vtx, ptp, _vtx); 
        }

        // In the case of AVAX Rewards, swap half for VTX and half for PTP 
        if (_wavax > 0) {
            _swapTraderJoe(wavax, ptp, _wavax); 
        }
        
        // Take fee, recheck PTP balance, and swap half PTP for xPTP
        uint256 _ptp = IERC20(ptp).balanceOf(address(this));
        if (_ptp > 0) {
            uint256 _keep = _ptp.mul(keep).div(keepMax);
            if (_keep > 0) {
                _takeFeeRewardToSnob(_keep, ptp);
            }

            _ptp = IERC20(ptp).balanceOf(address(this));

            address[] memory path = new address[](2);
            path[0] = ptp;
            path[1] = xptp;

            IERC20(ptp).safeApprove(joeRouter, 0);
            IERC20(ptp).safeApprove(joeRouter, _ptp.div(2));
            _swapTraderJoeWithPath(path, _ptp.div(2));
        }

        // Add liquidity for PTP/xPTP
        uint256 _xptp = IERC20(xptp).balanceOf(address(this));
        _ptp = IERC20(ptp).balanceOf(address(this));
        if (_xptp > 0 && _ptp > 0) {
            IERC20(xptp).safeApprove(joeRouter, 0);
            IERC20(xptp).safeApprove(joeRouter, _xptp);

            IERC20(ptp).safeApprove(joeRouter, 0);
            IERC20(ptp).safeApprove(joeRouter, _ptp);

            IJoeRouter(joeRouter).addLiquidity(
                xptp,
                ptp,
                _xptp,
                _ptp,
                0,
                0,
                address(this),
                now + 60
            );

            // Donates DUST
            _vtx = IERC20(vtx).balanceOf(address(this));
            _ptp = IERC20(ptp).balanceOf(address(this));
            _xptp = IERC20(xptp).balanceOf(address(this));
            _wavax = IERC20(wavax).balanceOf(address(this));
            if (_vtx > 0){
                IERC20(vtx).transfer(
                    IController(controller).treasury(),
                    _vtx
                );
            }
            
            if (_ptp > 0){
                IERC20(ptp).safeTransfer(
                    IController(controller).treasury(),
                    _ptp
                );
            }  
            
            if (_xptp > 0){
                IERC20(xptp).safeTransfer(
                    IController(controller).treasury(),
                    _xptp
                );
            }  

            if (_wavax > 0){
                IERC20(wavax).safeTransfer(
                    IController(controller).treasury(),
                    _wavax
                );
            }  
        }
        _distributePerformanceFeesAndDeposit();
    }
    
    // **** Views ****
    ///@notice Return the strategy name
    function getName() external override pure returns (string memory) {
        return "StrategyVtxPtpxPtp";
    }
}