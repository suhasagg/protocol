pragma solidity ^0.6.7;

import "../strategy-png-minichef-farm-base.sol";

contract StrategyPngAvaxBnb is StrategyPngMiniChefFarmBase {
    uint256 public _poolId = 78;

    // Token addresses
    address public png_avax_bnb_lp = 0xF776Ef63c2E7A81d03e2c67673fd5dcf53231A3f;
    address public bnb = 0x264c1383EA520f73dd837F915ef3a732e204a493;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        public
        StrategyPngMiniChefFarmBase(
            _poolId,
            png_avax_bnb_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}
    
    // **** State Mutations ****

    function harvest() public override onlyBenevolent {
        // Collects Token Fees
        IMiniChef(miniChef).harvest(poolId, address(this));

        // Take AVAX Rewards    
        uint256 _avax = address(this).balance;              // get balance of native AVAX
        if (_avax > 0) {                                    // wrap AVAX into ERC20
            WAVAX(wavax).deposit{value: _avax}();
        }

        // 10% is sent to treasury
        uint256 _wavax = IERC20(wavax).balanceOf(address(this));
        uint256 _png = IERC20(png).balanceOf(address(this));
        
        if (_wavax > 0) {
            uint256 _keep = _wavax.mul(keep).div(keepMax);
            if (_keep > 0) {
                _takeFeeWavaxToSnob(_keep);
            }  

            _wavax = IERC20(wavax).balanceOf(address(this));
        }


        if (_png > 0) {
            uint256 _keep = _png.mul(keep).div(keepMax);
            if (_keep > 0) {
                _takeFeePngToSnob(_keep);
            }

            _png = IERC20(png).balanceOf(address(this));  
        }

        // In the case of AVAX Rewards, swap half WAVAX for BNB
        if(_wavax > 0){
            IERC20(wavax).safeApprove(pangolinRouter, 0);
            IERC20(wavax).safeApprove(pangolinRouter, _wavax.div(2));   
            _swapPangolin(wavax, bnb, _wavax.div(2)); 
        }      

    
        // In the case of PNG Rewards, swap PNG for WAVAX and BNB
        if(_png > 0){
            IERC20(png).safeApprove(pangolinRouter, 0);
            IERC20(png).safeApprove(pangolinRouter, _png);   
            _swapPangolin(png, wavax, _png.div(2));
            _swapBaseToToken(_png.div(2), png, bnb); 
        }

        // Adds in liquidity for AVAX/BNB
        _wavax = IERC20(wavax).balanceOf(address(this));
        uint256 _bnb = IERC20(bnb).balanceOf(address(this));

        if (_wavax > 0 && _bnb > 0) {
            IERC20(wavax).safeApprove(pangolinRouter, 0);
            IERC20(wavax).safeApprove(pangolinRouter, _wavax);

            IERC20(bnb).safeApprove(pangolinRouter, 0);
            IERC20(bnb).safeApprove(pangolinRouter, _bnb);

            IPangolinRouter(pangolinRouter).addLiquidity(
                wavax,
                bnb,
                _wavax,
                _bnb,
                0,
                0,
                address(this),
                now + 60
            );

            // Donates DUST
            _wavax = IERC20(wavax).balanceOf(address(this));
            _bnb = IERC20(bnb).balanceOf(address(this));
            _png = IERC20(png).balanceOf(address(this));
            
            if (_wavax > 0){
                IERC20(wavax).transfer(
                    IController(controller).treasury(),
                    _wavax
                );
            }          
            
            if (_bnb > 0){
                IERC20(bnb).safeTransfer(
                    IController(controller).treasury(),
                    _bnb
                );
            }

            if (_png > 0){
                IERC20(png).safeTransfer(
                    IController(controller).treasury(),
                    _png
                );
            }
        }
    
        _distributePerformanceFeesAndDeposit();
    }

    // **** Views ****

    function getName() external pure override returns (string memory) {
        return "StrategyPngAvaxBnb";
    }
}