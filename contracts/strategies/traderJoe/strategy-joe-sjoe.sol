// SPDX-License-Identifier: MIT
pragma solidity ^0.6.7;

import "../strategy-joe-staking-rewards-base.sol";
import "../../interfaces/istablejoestaking.sol";

/// @title JOE-sJOE Staking Strategy
/// @notice Staking rewards strategy for TraderJoe's sJoe pool with USDC rewards
contract StrategyJoeSjoe is StrategyJoeStakingRewardsBase {
    // LP and Token addresses
    address public sjoe = 0x1a731B2299E22FbAC282E7094EdA41046343Cb51;               // Proxy contract for stableJoe
    address public usdc = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    
    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        public
        StrategyJoeStakingRewardsBase(
            sjoe,
            usdc,
            joe,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    /// @notice Specify path for USDC fees
    function _takeFeeUsdcToSnob(uint256 _keep) internal {
        address[] memory path = new address[](3);
        path[0] = usdc;
        path[1] = wavax;
        path[2] = snob;
        IERC20(joe).safeApprove(joeRouter, 0);
        IERC20(joe).safeApprove(joeRouter, _keep);
        _swapTraderJoeWithPath(path, _keep);
        uint _snob = IERC20(snob).balanceOf(address(this));
        uint256 _share = _snob.mul(revenueShare).div(revenueShareMax);
        IERC20(snob).safeTransfer(
            feeDistributor,
            _share
        );
        IERC20(snob).safeTransfer(
            IController(controller).treasury(),
            _snob.sub(_share)
        );
    }

    /**
     * @notice Harvests the rewards from the sJoe staking contract and reinvests 
     */
    function harvest() public override onlyBenevolent {
        // Calls deposit to trigger a harvest of the rewards
        IStableJoeStaking(sjoe).updateReward(usdc);
        IStableJoeStaking(sjoe).deposit(0);

        // Wraps native AVAX 
        uint256 _avax = address(this).balance;                          // get balance of native Avax
        if (_avax > 0) {                                                // wrap avax into ERC20
            WAVAX(wavax).deposit{value: _avax}();
        }

        // Get balance of USDC and collect reward fees
        uint256 _usdc = IERC20(usdc).balanceOf(address(this));

        if (_usdc > 0) {
            uint256 _keep = _usdc.mul(keep).div(keepMax);
            if (_keep > 0){
                _takeFeeUsdcToSnob(_keep);
            }
            _usdc = IERC20(usdc).balanceOf(address(this));

            // Swap usdc for joe
            _swapTraderJoe(usdc, joe, _usdc);
        }

        // Donates dust to the treasury
        _usdc = IERC20(usdc).balanceOf(address(this));
        if (_usdc > 0){
            IERC20(usdc).safeTransfer(
                IController(controller).treasury(),
                _usdc
            );
        }

        // Deposit JOE into sJOE contract
        _distributePerformanceFeesAndDeposit();
    }

    /// @notice Export the strategy name
    function getName() external override pure returns (string memory) {
        return "StrategyJoeSjoe";
    }
}	