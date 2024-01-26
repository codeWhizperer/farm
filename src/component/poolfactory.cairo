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

    fn deployPool(
        ref self: ContractState,
        implementation_hash: felt252,
        _stakedToken: ContractAddress,
        _rewardToken: ContractAddress,
        _rewardPerBlock: u256,
        _startBlock: u256,
        _bonusEndBlock: u256,
        _poolLimitPerUser: u256,
        _admin: ContractAddress,
        salt: felt252
    ) {
        self.ownable.assert_only_owner();
        assert(
            IERC20Dispatcher { contract_address: _stakedToken }.total_supply() >= 0,
            'supply must be greater than 0'
        );
        assert(
            IERC20Dispatcher { contract_address: _rewardToken }.total_supply() >= 0,
            'supply must be greater than 0'
        );
        assert(_stakedToken != _rewardToken, 'Tokens must be be different');

        let mut constructor_calldata: Array<felt252> = array![
            _stakedToken.into(),
            _rewardToken.into(),
            _rewardPerBlock.low.into(),
            _rewardPerBlock.high.into(),
            _startBlock.low.into(),
            _startBlock.high.into(),
            _bonusEndBlock.low.into(),
            _bonusEndBlock.high.into(),
            _poolLimitPerUser.low.into(),
            _poolLimitPerUser.high.into(),
            _admin.into()
        ];
        let class_hash: ClassHash = implementation_hash.try_into().unwrap();
        let result = deploy_syscall(class_hash, salt, constructor_calldata.span(), true);
        let (account_address, _) = result.unwrap_syscall();

        IpoolFarmDispatcher { contract_address: account_address }
            .initialize(
                _stakedToken,
                _rewardToken,
                _rewardPerBlock,
                _startBlock,
                _bonusEndBlock,
                _poolLimitPerUser,
                _admin
            );
            self.emit(NewWakandaPoolContract{poolAddress:account_address});
    }
}

