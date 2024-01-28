use farm::interfaces::pool::IpoolFarmDispatcherTrait;
use core::result::ResultTrait;
use farm::interfaces::erc20::IERC20DispatcherTrait;
use core::option::OptionTrait;
use farm::component::farm::GeneralPoolInitializable;
use farm::component::poolfactory::Factory;
use farm::component::token::TOKENERC20;
use farm::interfaces::erc20::IERC20Dispatcher;
use farm::interfaces::pool::IpoolFarmDispatcher;
use starknet::{
    ContractAddress, get_caller_address, syscalls::call_contract_syscall, class_hash::ClassHash,
    class_hash::Felt252TryIntoClassHash, syscalls::deploy_syscall, SyscallResultTrait
};
use core::traits::Into;
use core::traits::TryInto;
use snforge_std::{
    get_class_hash, ContractClassTrait, declare, start_prank, stop_prank, CheatTarget
};
use debug::PrintTrait;
use starknet::info::get_block_number;
use core::integer::upcast;

// deploy token
const recipient_staked: felt252 = 123;
const recipient_reward: felt252 = 124;
const caller_farm_pool: felt252 = 125;
fn setup() -> (ContractAddress, ContractAddress) {
    let recipient_stakedToken: ContractAddress = recipient_staked.try_into().unwrap();
    let recipient_rewardToken: ContractAddress = recipient_reward.try_into().unwrap();

    // let recipient_rewardToken = makeAddress('rewardToken');
    let token_class_hash: ClassHash = declare('TOKENERC20').class_hash.try_into().unwrap();
    let mut staked_constructor_calldata = array![
        recipient_stakedToken.into(), 'StakedToken', 18, 10000, 'STK'
    ];
    let mut reward_constructor_calldata = array![
        recipient_rewardToken.into(), 'RewardToken', 18, 10000, 'RTK'
    ];

    let stakedToken = deploy_syscall(
        token_class_hash, 1000, staked_constructor_calldata.span(), true
    );
    let rewardToken = deploy_syscall(
        token_class_hash, 1000, reward_constructor_calldata.span(), true
    );

    let (staked_token_address, _) = stakedToken.unwrap_syscall();
    let (reward_token_address, _) = rewardToken.unwrap_syscall();

    return (staked_token_address, reward_token_address);
}

// setup for factory:

fn deploy_contract() {
    let (staked_token_address, reward_token_address) = setup();
let blocknumber:u256 = get_block_number().into() + 1;
let bonusBlockEnd:u256 = get_block_number().into() + 201; 
    let caller = makeAddress('caller');
    let admin = makeAddress('admin');
    let pool_class_hash: ClassHash = declare('GeneralPoolInitializable')
        .class_hash
        .try_into()
        .unwrap();

    let mut pool_constructor_calldata = array![caller.try_into().unwrap().into()];
    let pool = deploy_syscall(pool_class_hash, 100000, pool_constructor_calldata.span(), true);
    let (pool_address, _) = pool.unwrap_syscall();
    //initialze pool
    IpoolFarmDispatcher{contract_address:pool_address}.initialize(staked_token_address, reward_token_address,10000,block_number, bonusBlockEnd, 0, admin.into(), 10000);

}

// let block_number: u256 = get_block_number().into() + 1;
// let amount:felt252 = 10000;
// let _bonusEndBlock: u256 = get_block_number().into() + 1;

#[test]
fn test_initialize(){
    
}

#[test]
fn test_staked_token_name() {
    let (staked_token_address, reward_token_address) = setup();
    let staked_dispatcher = IERC20Dispatcher { contract_address: staked_token_address }.name();
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_token_address }.name();
    assert(staked_dispatcher == 'StakedToken', 'invalid_name');
    assert(reward_dispatcher == 'RewardToken', 'invalid_name');
}

#[test]
fn test_token_holder_balance() {
    let (staked_token_address, reward_token_address) = setup();
    let staked_dispatcher = IERC20Dispatcher { contract_address: staked_token_address }
        .balance_of(recipient_staked.try_into().unwrap());
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_token_address }
        .balance_of(recipient_reward.try_into().unwrap());
    assert(staked_dispatcher == 10000, 'invalid_balance');
    assert(reward_dispatcher == 10000, 'invalid_balance');
}


// #[test]
// fn test_deposit() {
//     let contract_address = deploy_contract();
//     let (staked_token_address, _) = setup();

//     // start_prank(CheatTarget::One(contract_address), recipient_staked.try_into().unwrap());
//     let dispatcher = IpoolFarmDispatcher { contract_address }.deposit(100);
//     let token_staked_balance = IERC20Dispatcher { contract_address: staked_token_address }
//         .balance_of(recipient_staked.try_into().unwrap());
//     assert(token_staked_balance == 9900, 'invalid_balance');
//     // stop_prank(CheatTarget::One(contract_address))
// }
// setup

// fn setup() -> ContractAddress {
//     let caller = makeAddress('caller');
//     let admin = makeAddress('admin');
//     let user1 = makeAddress('user1');
//     let uer2 = makeAddress('user2');
//     let pool_contract_hash = declare('GeneralPoolInitializable').class_hash;
//     let contract = declare('Factory');
//     let calldata = array![];
// }

fn makeAddress(name: felt252) -> ContractAddress {
    name.try_into().unwrap()
}
