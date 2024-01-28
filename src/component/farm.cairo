use starknet::{ContractAddress, get_caller_address};

#[starknet::contract]
mod GeneralPoolInitializable {
    use core::traits::Into;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use core::starknet::event::EventEmitter;
    use core::traits::MulEq;
    use openzeppelin::access::ownable::interface::IOwnable;
    use farm::interfaces::erc20::IERC20DispatcherTrait;
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::access::ownable::OwnableComponent;
    use farm::interfaces::erc20;
    use farm::interfaces::erc20::IERC20Dispatcher;
    use core::integer::{U256Sub, upcast, U256Mul, U256Div, U256Add};
    use farm::utils::helper::pow;
    use starknet::info::{get_block_number, get_contract_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnershipTransferred);

    #[storage]
    struct Storage {
        GeneralPoolFactory: ContractAddress,
        hasUserLimit: bool,
        isInitialized: bool,
        accTokenPerShare: u256,
        bonusEndBlock: u256,
        startBlock: u256,
        lastRewardBlock: u256,
        poolLimitPerUser: u256,
        rewardPerBlock: u256,
        PRECISION_FACTOR: u256,
        rewardToken: ContractAddress,
        stakedToken: ContractAddress,
        userInfo: LegacyMap<ContractAddress, UserInfo>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }
    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct UserInfo {
        amount: u256,
        rewardDebt: u256
    }


    // EVENTS

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnershipTransferred: OwnableComponent::Event,
        DepositAmount: DepositAmount,
        withdrawAmount: WithdrawAmount,
        EmergencyWithdraw: EmergencyWithdraw,
        AdminTokenRecovery: AdminTokenRecovery,
        NewPoolLimit: NewPoolLimit,
        NewRewardPerBlock: NewRewardPerBlock,
        NewStartAndEndBlocks: NewStartAndEndBlocks
    }

    #[derive(Drop, starknet::Event)]
    struct DepositAmount {
        caller: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawAmount {
        caller: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyWithdraw {
        caller: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct AdminTokenRecovery {
        contract: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct NewPoolLimit {
        poolLimitPerUser: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct NewRewardPerBlock {
        rewardPerBlock: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct NewStartAndEndBlocks {
        startBlock: u256,
        bonusEndBlock: u256
    }


    // Errors
    mod Errors {
        const STATUS: felt252 = 'Already initialized';
        const FACTORY: felt252 = 'Not Factory';
        const TOKEN_NOT_EQUAL: felt252 = 'cannot be same address';
        const AMOUNT_ABOVE_LIMIT: felt252 = 'user amount above limit';
        const WITHDRAW_TOO_HIGH: felt252 = 'amount to withdraw too high';
        const NOT_STAKED_TOKEN: felt252 = 'cannot be staked token';
        const NOT_REWARD_TOKEN: felt252 = 'cannot be reward token';
        const LIMIT_MUST_BE_SET: felt252 = 'limit must be set';
        const LIMIT_MUST_BE_HIGHER: felt252 = 'limit must be higher';
        const POOL_HAS_STARTED: felt252 = 'pool has started';
        const NEW_START_BLOCK_MUST_BE_LOWER: felt252 = 'new startblock must be lower';
        const NEW_START_BLOCK_MUST_BE_HIGHER: felt252 = 'new startblock must be higher';
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let caller: ContractAddress = get_caller_address();
        self.GeneralPoolFactory.write(caller);
    }

    //*
    //  * @notice Initialize the contract
    //  * @param _stakedToken: staked token address
    //  * @param _rewardToken: reward token address
    //  * @param _rewardPerBlock: reward per block (in rewardToken)
    //  * @param _startBlock: start block
    //  * @param _bonusEndBlock: end block
    //  * @param _poolLimitPerUser: pool limit per user in stakedToken (if any, else 0)
    // * @param _admin: admin address with ownership
    // */
    fn initialize(
        ref self: ContractState,
        _stakedToken: ContractAddress,
        _rewardToken: ContractAddress,
        _rewardPerBlock: u256,
        _startBlock: u256,
        _bonusEndBlock: u256,
        _poolLimitedPerUser: u256,
        _admin: ContractAddress
    ) {
        let caller = get_caller_address();
        let isInitialized = self.isInitialized.read();
        assert(!isInitialized, Errors::STATUS);
        assert(caller == self.GeneralPoolFactory.read(), Errors::FACTORY);

        // make this contract initialized
        self.isInitialized.write(true);
        self.stakedToken.write(_stakedToken);
        self.rewardToken.write(_rewardToken);
        assert(_stakedToken != _rewardToken, Errors::TOKEN_NOT_EQUAL);
        self.rewardPerBlock.write(_rewardPerBlock);
        self.startBlock.write(_startBlock);
        self.bonusEndBlock.write(_bonusEndBlock);

        if (_poolLimitedPerUser > 0) {
            self.hasUserLimit.write(true);
            self.poolLimitPerUser.write(_poolLimitedPerUser);
        }

        let decimalsRewardToken = IERC20Dispatcher { contract_address: _rewardToken }.decimals();
        assert(decimalsRewardToken < 30, 'Must be inferiro to 30');
        // not sure if calc is well intepreted from solidity code
        let precision_decimal_result: u256 = U256Sub::sub(30, decimalsRewardToken);
        self.PRECISION_FACTOR.write(pow(10, precision_decimal_result));

        // set the lastRewardBlock as the startBlock
        self.lastRewardBlock.write(_startBlock);
        self.ownable.transfer_ownership(_admin);
    }


    // @notice Deposit staked tokens and collect reward tokens (if any)
    // @param _amount: amount to withdraw (in rewardToken)

    fn deposit(ref self: ContractState, _amount: u256) {
        let caller = get_caller_address();
        let mut user = self.userInfo.read(caller);
        let hasUserLimit = self.hasUserLimit.read();
        let user_deposit = U256Add::add(_amount, user.amount);
        let poolLimitPerUser = self.poolLimitPerUser.read();

        let accTokenPerShare = self.accTokenPerShare.read();
        let precision_factor = self.PRECISION_FACTOR.read();
        let user_amount_mul = U256Mul::mul(user.amount, accTokenPerShare) / precision_factor;
        let pending = U256Sub::sub(user_amount_mul, user.rewardDebt);
        let rewardToken = self.rewardToken.read();
        let stakedToken = self.stakedToken.read();

        if (hasUserLimit) {
            assert(user_deposit <= poolLimitPerUser, Errors::AMOUNT_ABOVE_LIMIT);
        }
        self._updatePool();

        if (user.amount > 0) {
            if (pending > 0) {
                IERC20Dispatcher { contract_address: rewardToken }.transfer(caller, pending);
            }
        }

        if (_amount > 0) {
            let user_amount = U256Add::add(user.amount, _amount);
            IERC20Dispatcher { contract_address: stakedToken }
                .transfer_from(caller, get_contract_address(), _amount);
        }

        let user_reward_debt = U256Mul::mul(user.amount, accTokenPerShare) / precision_factor;
        user.rewardDebt = user_reward_debt;

        self.emit(DepositAmount { caller, amount: _amount });
    }


    //* @notice Withdraw staked tokens and collect reward tokens
    //* @param _amount: amount to withdraw (in rewardToken)
    fn withdraw(ref self: ContractState, _amount: u256) {
        let caller = get_caller_address();
        let mut user = self.userInfo.read(caller);
        assert(user.amount >= _amount, Errors::WITHDRAW_TOO_HIGH);
        self._updatePool();
        let accTokenPerShare = self.accTokenPerShare.read();
        let precision_factor = self.PRECISION_FACTOR.read();
        let user_amount_mul = U256Mul::mul(user.amount, accTokenPerShare) / precision_factor;
        let pending = U256Sub::sub(user_amount_mul, user.rewardDebt);
        let rewardToken = self.rewardToken.read();
        let stakedToken = self.stakedToken.read();
        if (_amount > 0) {
            user.amount = U256Sub::sub(user.amount, _amount);
            IERC20Dispatcher { contract_address: stakedToken }.transfer(caller, _amount);
        }

        if (pending > 0) {
            IERC20Dispatcher { contract_address: rewardToken }.transfer(caller, pending);
        }
        let user_reward_debt = U256Mul::mul(user.amount, accTokenPerShare) / precision_factor;
        user.rewardDebt = user_reward_debt;
        self.emit(WithdrawAmount { caller, amount: _amount });
    }


    //* @notice Withdraw staked tokens without caring about rewards rewards
    // * @dev Needs to be for emergency.

    fn emergencyWithdraw(ref self: ContractState) {
        let caller = get_caller_address();
        let mut user = self.userInfo.read(caller);
        let amountToTransfer = user.amount;
        let stakedToken = self.stakedToken.read();

        user.amount = 0;
        user.rewardDebt = 0;

        if (amountToTransfer > 0) {
            IERC20Dispatcher { contract_address: stakedToken }.transfer(caller, amountToTransfer);
        }
        self.emit(EmergencyWithdraw { caller, amount: user.amount });
    }

    //   * @notice Stop rewards
    // * @dev Only callable by owner. Needs to be for emergency.

    fn emergencyRewardWithdraw(ref self: ContractState, _amount: u256) {
        self.ownable.assert_only_owner();
        let rewardToken = self.rewardToken.read();
        let caller = get_caller_address();
        IERC20Dispatcher { contract_address: rewardToken }.transfer(caller, _amount);
    }

    //  * @notice It allows the admin to recover wrong tokens sent to the contract
    //  * @param _tokenAddress: the address of the token to withdraw
    //  * @param _tokenAmount: the number of tokens to withdraw
    //  * @dev This function is only callable by admin.

    fn recoverWrongTokens(
        ref self: ContractState, _tokenAddress: ContractAddress, _tokenAmount: u256
    ) {
        self.ownable.assert_only_owner();
        let caller = get_caller_address();
        let rewardToken = self.rewardToken.read();
        let stakedToken = self.stakedToken.read();

        assert(_tokenAddress != stakedToken, Errors::NOT_STAKED_TOKEN);
        assert(_tokenAddress != rewardToken, Errors::NOT_REWARD_TOKEN);
        IERC20Dispatcher { contract_address: _tokenAddress }.transfer(caller, _tokenAmount);
        self.emit(AdminTokenRecovery { contract: _tokenAddress, amount: _tokenAmount });
    }

    //* @notice Stop rewards
    //* @dev Only callable by owner
    fn stopReward(ref self: ContractState) {
        self.ownable.assert_only_owner();
        let blocknumber: u256 = get_block_number().into();
        self.bonusEndBlock.write(blocknumber);
    }


    // * @notice Update pool limit per user
    // * @dev Only callable by owner.
    // * @param _hasUserLimit: whether the limit remains forced
    // * @param _poolLimitPerUser: new pool limit per user

    fn updatePoolLimitPerUser(
        ref self: ContractState, _hasUserLimit: bool, _poolLimitPerUser: u256
    ) {
        self.ownable.assert_only_owner();
        let hasUserLimit = self.hasUserLimit.read();
        let poolLimitPerUser = self.poolLimitPerUser.read();
        assert(hasUserLimit, Errors::LIMIT_MUST_BE_SET);
        if (_hasUserLimit) {
            assert(_poolLimitPerUser > poolLimitPerUser, Errors::LIMIT_MUST_BE_HIGHER);
            self.poolLimitPerUser.write(_poolLimitPerUser);
        } else {
            self.hasUserLimit.write(_hasUserLimit);
            self.poolLimitPerUser.write(0);
        }
        self.emit(NewPoolLimit { poolLimitPerUser })
    }


    // * @notice Update reward per block
    //  * @dev Only callable by owner.
    //* @param _rewardPerBlock: the reward per block

    fn updateRewardPerBlock(ref self: ContractState, _rewardPerBlock: u256) {
        self.ownable.assert_only_owner();
        let blocknumber: u256 = get_block_number().into();
        let startBlock = self.startBlock.read();
        assert(blocknumber < startBlock, Errors::POOL_HAS_STARTED);
        self.emit(NewRewardPerBlock { rewardPerBlock: _rewardPerBlock });
    }

    // * @notice It allows the admin to update start and end blocks
    // * @dev This function is only callable by owner.
    // * @param _startBlock: the new start block
    // * @param _bonusEndBlock: the new end block

    fn updateStartAndEndBlock(ref self: ContractState, _startBlock: u256, _bonusEndBlock: u256) {
        self.ownable.assert_only_owner();
        let blocknumber: u256 = get_block_number().into();
        let startBlock = self.startBlock.read();
        assert(blocknumber < startBlock, Errors::POOL_HAS_STARTED);
        assert(_startBlock < _bonusEndBlock, Errors::NEW_START_BLOCK_MUST_BE_LOWER);
        assert(blocknumber < _startBlock, Errors::NEW_START_BLOCK_MUST_BE_HIGHER);

        self.startBlock.write(_startBlock);
        self.bonusEndBlock.write(_bonusEndBlock);
        // Set the lastRewardBlock as the startBlock
        self.lastRewardBlock.write(startBlock);
        self.emit(NewStartAndEndBlocks { startBlock: _startBlock, bonusEndBlock: _bonusEndBlock })
    }

    //  * @notice View function to see pending reward on frontend.
    //  * @param _user: user address
    //  * @return Pending reward for a given user

    fn pendingReward(ref self: ContractState, _address: ContractAddress) -> u256 {
        let mut user = self.userInfo.read(_address);
        let stakedToken = self.stakedToken.read();
        let address_this = get_contract_address();
        let lastRewardPerBlock = self.lastRewardBlock.read();
        let blocknumber: u256 = get_block_number().into();
        let rewardPerBlock = self.rewardPerBlock.read();
        let accTokenPerShare = self.accTokenPerShare.read();
        let precision_factor = self.PRECISION_FACTOR.read();

        let stakedTokenSupply = IERC20Dispatcher { contract_address: stakedToken }
            .balance_of(address_this);

        if (blocknumber > lastRewardPerBlock && stakedTokenSupply != 0) {
            let multiplier = self._getMultiplier(lastRewardPerBlock, blocknumber);
            let tkdReward = U256Mul::mul(multiplier, rewardPerBlock);
            let adjustedTokenPerShareCal = U256Mul::mul(tkdReward, precision_factor)
                / stakedTokenSupply.into();
            let adjustedTokenPerShare = U256Add::add(accTokenPerShare, adjustedTokenPerShareCal);
            let user_reward_cal = U256Mul::mul(user.amount, adjustedTokenPerShare)
                / precision_factor;
            let user_reward = U256Sub::sub(user_reward_cal, user.rewardDebt);
            return user_reward;
        } else {
            let user_reward_debt_cal = U256Mul::mul(user.amount, accTokenPerShare)
                / precision_factor;
            return U256Sub::sub(user_reward_debt_cal, user.rewardDebt);
        }

      
    }

      fn initialize_status(self:@ContractState) -> bool{
            return self.isInitialized.read();
        }

    ////internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionTrait {
        //@notice Returns reward multiplier over the given _from to _to block
        //@param _from: block to start
        //_to: block to finish
        fn _getMultiplier(ref self: ContractState, _from: u256, _to: u256) -> u256 {
            let bonusEndBlock = self.bonusEndBlock.read();
            if (_to <= bonusEndBlock) {
                return U256Sub::sub(_to, _from);
            } else if (_from >= bonusEndBlock) {
                return 0;
            } else {
                return U256Sub::sub(bonusEndBlock, _from);
            }
        }

        //@notice Update reward varibles of the given pool to be up-to-date
        fn _updatePool(ref self: ContractState) {
            let blocknumber: u256 = get_block_number().into();
            let lastRewardBlock = self.lastRewardBlock.read();
            if (blocknumber <= lastRewardBlock) {
                return;
            }
            let address_this = get_contract_address();
            let stakedToken = self.stakedToken.read();
            let stakedTokenSupply = IERC20Dispatcher { contract_address: stakedToken }
                .balance_of(address_this);

            if stakedTokenSupply == 0 {
                self.lastRewardBlock.write(blocknumber)
            }
            let multiplier = self._getMultiplier(lastRewardBlock, blocknumber);
            let rewardPerBlock = self.rewardPerBlock.read();
            let tkdReward = U256Mul::mul(multiplier, rewardPerBlock);
            let accTokenPerShare = self.accTokenPerShare.read();
            let precisionFactor = self.PRECISION_FACTOR.read();
            let tkd_mul_precion_factor = U256Mul::mul(tkdReward, precisionFactor);
            let tkd_div_staked_token_supply = U256Div::div(
                tkd_mul_precion_factor, stakedTokenSupply.into()
            );
            let accTokenPerFinalValue = U256Add::add(
                tkd_mul_precion_factor, tkd_div_staked_token_supply
            );
            self.accTokenPerShare.write(accTokenPerFinalValue);
            self.lastRewardBlock.write(blocknumber);
        }
    }
}

