// SPDX-License-Identifier: MIT
pragma solidity ^0.6.7;

import "../strategy-joe-rush-farm-base.sol";

contract StrategyJoeAvaxOhLp is StrategyJoeRushFarmBase {
    uint256 public avax_oh_poolId = 4;

    address public joe_avax_oh_lp = 0x361B625c074c736ef2d959e983b4478aA23a5d19;
    address public oh = 0x937E077aBaEA52d3abf879c9b9d3f2eBd15BAA21;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        public
        StrategyJoeRushFarmBase(
            avax_oh_poolId,
            joe_avax_oh_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** State Mutations ****

    function harvest() public override onlyBenevolent {
        // Anyone can harvest it at any given time.
        // I understand the possibility of being frontrun
        // But AVAX is a dark forest, and I wanna see how this plays out
        // i.e. will be be heavily frontrunned?
        //      if so, a new strategy will be deployed.

        // Collects Joe tokens
        IMasterChefJoeV2(masterChefJoeV3).deposit(poolId, 0);

        uint256 _joe = IERC20(joe).balanceOf(address(this));
        if (_joe > 0) {
            // 10% is sent to treasury
            uint256 _keep = _joe.mul(keep).div(keepMax);
            uint256 _amount = _joe.sub(_keep).div(2);
            if (_keep > 0) {
                _takeFeeJoeToSnob(_keep);
            }
            IERC20(joe).safeApprove(joeRouter, 0);
            IERC20(joe).safeApprove(joeRouter, _joe.sub(_keep));

            _swapTraderJoe(joe, wavax, _amount);
            _swapTraderJoe(joe, oh, _amount);
        }

        //Take Avax Rewards    
        uint256 _avax = address(this).balance;            //get balance of native Avax
        if (_avax > 0) {                                 //wrap avax into ERC20
            WAVAX(wavax).deposit{value: _avax}();
        }
        
        uint256 _wavax = IERC20(wavax).balanceOf(address(this));
        if (_wavax > 0) {
             uint256 _keep2 = _wavax.mul(keep).div(keepMax);
            uint256 _amount2 = _wavax.sub(_keep2).div(2);
            if (_keep2 > 0){
                _takeFeeWavaxToSnob(_keep2);
            }

        //convert Avax Rewards
            IERC20(wavax).safeApprove(joeRouter, 0);
            IERC20(wavax).safeApprove(joeRouter, _amount2);   
            _swapTraderJoe(wavax, oh, _amount2);
        }

        // Adds in liquidity for AVAX/oh
        _wavax = IERC20(wavax).balanceOf(address(this));

        uint256 _oh = IERC20(oh).balanceOf(address(this));

        if (_wavax > 0 && _oh > 0) {
            IERC20(wavax).safeApprove(joeRouter, 0);
            IERC20(wavax).safeApprove(joeRouter, _wavax);

            IERC20(oh).safeApprove(joeRouter, 0);
            IERC20(oh).safeApprove(joeRouter, _oh);

            IJoeRouter(joeRouter).addLiquidity(
                wavax,
                oh,
                _wavax,
                _oh,
                0,
                0,
                address(this),
                now + 60
            );

            // Donates DUST
            IERC20(wavax).transfer(
                IController(controller).treasury(),
                IERC20(wavax).balanceOf(address(this))
            );
            IERC20(oh).safeTransfer(
                IController(controller).treasury(),
                IERC20(oh).balanceOf(address(this))
            );
        }

        _distributePerformanceFeesAndDeposit();
    }

    // **** Views ****

    function getName() external pure override returns (string memory) {
        return "StrategyJoeAvaxOhLp";
    }
}