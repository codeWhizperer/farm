use starknet::ContractAddress;
#[starknet::interface]
trait IpoolFarm<TState> {
    fn initialize(
        ref self: TState,
        _stakedToken: ContractAddress,
        _rewardToken: ContractAddress,
        _rewardPerBlock: u256,
        _startBlock: u256,
        _bonusEndBlock: u256,
        _poolLimitedPerUser: u256,
        _admin: ContractAddress
    );
    fn deposit(ref self: TState, _amount: u256);
    fn withdraw(ref self: TState, _amount: u256);
    fn emergencyWithdraw(ref self: TState);
    fn emergencyRewardWithdraw(ref self: TState, _amount: u256);
    fn recoverWrongTokens(ref self: TState, _tokenAddress: ContractAddress, _tokenAmount: u256);
    fn stopReward(ref self: TState);
    fn updatePoolLimitPerUser(ref self: TState, _hasUserLimit: bool, _poolLimitPerUser: u256);
    fn updateRewardPerBlock(ref self: TState, _rewardPerBlock: u256);
    fn updateStartAndEndBlock(ref self: TState, _startBlock: u256, _bonusEndBlock: u256);
    fn pendingReward(ref self: TState, _address: ContractAddress) -> u256;
    fn initialize_status(self:@TState) -> bool;
    fn getCaller(self: @TState) -> ContractAddress;
}
