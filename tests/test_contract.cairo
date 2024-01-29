use farm::interfaces::factory::IFactoryDispatcherTrait;
use farm::interfaces::pool::IpoolFarmDispatcherTrait;
use core::result::ResultTrait;
use farm::interfaces::erc20::IERC20DispatcherTrait;
use core::option::OptionTrait;
use farm::component::farm::GeneralPoolInitializable;
use farm::component::poolfactory::Factory;
use farm::component::token::TOKENERC20;
use farm::interfaces::erc20::IERC20Dispatcher;
use farm::interfaces::pool::IpoolFarmDispatcher;
use farm::interfaces::factory::IFactoryDispatcher;
use starknet::{
    ContractAddress, get_caller_address, syscalls::call_contract_syscall, class_hash::ClassHash,
    class_hash::Felt252TryIntoClassHash, syscalls::deploy_syscall, SyscallResultTrait,
    class_hash_to_felt252
};
use integer::u256_from_felt252;
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

// setup_factory

fn deploy_contract_factory() -> (ContractAddress, ContractAddress) {
    // declare pool contract and extract class hash
    let factory_contract = declare('Factory');
    let pool_class_hash = declare('GeneralPoolInitializable').class_hash.try_into().unwrap();
    let factory_address = factory_contract.deploy(@array![]).unwrap();
    let dispatcher_pool_factory_address = IFactoryDispatcher { contract_address: factory_address }
        .deployPool(class_hash_to_felt252(pool_class_hash), 54663);
    return (dispatcher_pool_factory_address, factory_address);
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


#[test]
fn test_initialize_status_and_deployer_before_initialization() {
    let (dispatcher_pool_factory_address, factory_address) = deploy_contract_factory();
    let msg_sender: ContractAddress = makeAddress('caller');

    start_prank(CheatTarget::One(dispatcher_pool_factory_address), factory_address);
    let dispatcher = IpoolFarmDispatcher { contract_address: dispatcher_pool_factory_address };
    let status = dispatcher.initialize_status();
    let caller = dispatcher.getCaller();
    // assert(contract_factory_address == caller, 'invalid_caller');
    assert(status == false, 'initialized');
    stop_prank(CheatTarget::One(dispatcher_pool_factory_address))
}

#[test]
fn test_initiliaze_pool() {
    let block_number: u256 = get_block_number().into() + 1;
    let endblock: u256 = get_block_number().into() + 201;
    let admin: ContractAddress = makeAddress('admin');
    let (staked_token_address, reward_token_address) = setup();
    let (dispatcher_pool_factory_address, factory_address) = deploy_contract_factory();
    start_prank(CheatTarget::One(dispatcher_pool_factory_address), factory_address);
    let dispatcher = IpoolFarmDispatcher { contract_address: dispatcher_pool_factory_address };
    dispatcher.initialize(
            staked_token_address,
            reward_token_address,
            10000,
            block_number,
            endblock,
            0,
            admin
        );
    let status = dispatcher.initialize_status();
    assert(status == true, 'not_initialized status');
    stop_prank(CheatTarget::One(dispatcher_pool_factory_address))
}

fn makeAddress(name: felt252) -> ContractAddress {
    name.try_into().unwrap()
}
