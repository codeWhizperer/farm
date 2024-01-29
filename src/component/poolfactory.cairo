#[starknet::contract]
mod Factory {
    use farm::interfaces::pool::IpoolFarmDispatcherTrait;
    use farm::interfaces::erc20::IERC20DispatcherTrait;
    use core::traits::TryInto;
    use core::result::ResultTrait;
    use core::hash::HashStateTrait;
    use farm::interfaces::erc20::IERC20Dispatcher;
    use farm::interfaces::pool::IpoolFarmDispatcher;

    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::ownable::OwnableComponent;
    use starknet::{
        ContractAddress, get_caller_address, syscalls::call_contract_syscall, class_hash::ClassHash,
        class_hash::Felt252TryIntoClassHash, syscalls::deploy_syscall, SyscallResultTrait
    };
    component!(path: OwnableComponent, storage: ownable, event: OwnershipTransferred);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    // EVENTS

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnershipTransferred: OwnableComponent::Event,
        NewWakandaPoolContract: NewWakandaPoolContract
    }

    #[derive(Drop, starknet::Event)]
    struct NewWakandaPoolContract {
        poolAddress: ContractAddress
    }
    // * @notice Deploy the pool
    // * @param _stakedToken: staked token address
    // * @param _rewardToken: reward token address
    // * @param _rewardPerBlock: reward per block (in rewardToken)
    // * @param _startBlock: start block
    // * @param _endBlock: end block
    // * @param _poolLimitPerUser: pool limit per user in stakedToken (if any, else 0)
    // * @param _admin: admin address with ownership
    // * @return address of new smart chef contract
    #[external(v0)]
    fn deployPool(
        ref self: ContractState, implementation_hash: felt252, salt: felt252
    ) -> ContractAddress {
        // let caller: ContractAddress = get_caller_address();
        // let mut constructor_calldata = array![caller.into()];
        let mut calldata = array![];
        let class_hash: ClassHash = implementation_hash.try_into().unwrap();
        let result = deploy_syscall(class_hash, salt, calldata.span(), true);
        let (account_address, _) = result.unwrap_syscall();
        self.emit(NewWakandaPoolContract { poolAddress: account_address });

        return account_address;
    // IpoolFarmDispatcher { contract_address: account_address }
    //     .initialize(
    //         _stakedToken,
    //         _rewardToken,
    //         _rewardPerBlock,
    //         _startBlock,
    //         _bonusEndBlock,
    //         _poolLimitPerUser,
    //         _admin
    //     );
    }
}

