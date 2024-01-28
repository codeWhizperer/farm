  use starknet::ContractAddress;
  #[starknet::interface]
  trait IFactory<TState>{
   fn deployPool(
        ref self: TState,
        implementation_hash: felt252,
        // _stakedToken: ContractAddress,
        // _rewardToken: ContractAddress,
        // _rewardPerBlock: u256,
        // _startBlock: u256,
        // _bonusEndBlock: u256,
        // _poolLimitPerUser: u256,
        // _admin: ContractAddress,
        salt: felt252
    ) -> ContractAddress;
  }