import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { AxialControllerV4__factory } from '../../typechain';
import { getControllerArgs } from './args';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy} = deployments;
    const {deployer} = await getNamedAccounts();
    const contract_name = (new AxialControllerV4__factory()).contractName;
    const deployed = await deploy(contract_name, {
        from: deployer,
        args: getControllerArgs(contract_name),
        contract: contract_name,
        log: true
    }); 
};

func.tags = ['controllers', 'axial']
export default func;
