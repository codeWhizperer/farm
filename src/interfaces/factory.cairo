  use starknet::ContractAddress;
  #[starknet::interface]
  trait IFactory<TState>{
   fn deployPool(
        ref self: TState,
        implementation_hash: felt252,
        salt: felt252
    ) -> ContractAddress;
  }